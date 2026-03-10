import 'dart:io';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'connection.dart';

class Migrations {
  /// Entry point for database initialization and migrations
  static Future<void> initializeDatabase() async {
    try {
      // 1. Initialize the shared connection pool
      await DBConnection.initialize();
      
      final conn = DBConnection.getConnection();
      final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
      final dbName = env['DB_NAME'] ?? 'fs_hub_db';

      print('Checking database schema for $dbName...');

      // 2. Check if the 'users' table exists. If not, apply initial schema.
      final tableCheck = await conn.execute(
        "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'users'",
        {'db': dbName},
      );

      final usersExist = int.tryParse(tableCheck.rows.first.colByName('cnt').toString()) ?? 0;
      
      if (usersExist == 0) {
        print('Initial schema not found. Applying lib/database/schema.sql...');
        final schemaFile = File('lib/database/schema.sql');
        if (await schemaFile.exists()) {
          final schemaSQL = await schemaFile.readAsString();
          // mysql_client execute() doesn't always support multiple statements in one call.
          // We split by semicolon as a best effort.
          final statements = schemaSQL.split(';');
          for (var stmt in statements) {
            if (stmt.trim().isNotEmpty) {
              await conn.execute(stmt);
            }
          }
          print('Initial schema applied successfully.');
        } else {
          print('CRITICAL: lib/database/schema.sql not found!');
        }
      }

      // 3. Apply incremental migrations (idempotent)
      await _runIncrementalMigrations(conn, dbName);

      // 3b. Seed missing permissions for existing databases
      await _seedMissingPermissions(conn);
      
      // 4. Reset all users to offline on startup (in case of previous crash)
      print('Resetting user presence states...');
      await conn.execute('UPDATE users SET is_online = FALSE');

      print('Database initialization complete.');
    } catch (e, stack) {
      print('CRITICAL: Database initialization failed: $e\n$stack');
    }
  }

  static Future<void> _runIncrementalMigrations(_DBProxy conn, String dbName) async {
    // A. Ensure 'message_idempotency' table exists
    await _ensureTable(conn, dbName, 'message_idempotency', '''
      CREATE TABLE message_idempotency (
          id INT AUTO_INCREMENT PRIMARY KEY,
          client_message_id VARCHAR(255) NOT NULL,
          conversation_id INT NOT NULL,
          server_message_id INT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY unique_client_conv (client_message_id, conversation_id),
          FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
          FOREIGN KEY (server_message_id) REFERENCES messages(id) ON DELETE CASCADE,
          INDEX idx_client_message (client_message_id),
          INDEX idx_server_message (server_message_id)
      )
    ''');

    // B. Ensure 'refresh_tokens' table exists
    await _ensureTable(conn, dbName, 'refresh_tokens', '''
      CREATE TABLE refresh_tokens (
          id INT AUTO_INCREMENT PRIMARY KEY,
          user_id VARCHAR(50) NOT NULL,
          token VARCHAR(1024) NOT NULL,
          revoked BOOLEAN DEFAULT FALSE,
          expires_at TIMESTAMP NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          INDEX idx_user_id (user_id),
          INDEX idx_token (token(255))
      )
    ''');

    // C. Ensure 'demands' table exists (used by /v1/demands)
    await _ensureTable(conn, dbName, 'demands', '''
      CREATE TABLE demands (
          id INT AUTO_INCREMENT PRIMARY KEY,
          type VARCHAR(50) NOT NULL,
          description TEXT,
          status VARCHAR(30) DEFAULT 'pending',
          requester_id VARCHAR(50) NOT NULL,
          handled_by VARCHAR(50) NULL,
          resolution_notes TEXT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_requester_id (requester_id),
          INDEX idx_status (status),
          INDEX idx_type (type)
      )
    ''');

    // D. Ensure timestamp columns exist on demands (backward compatible)
    await _ensureColumn(conn, dbName, 'demands', 'created_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP');
    await _ensureColumn(conn, dbName, 'demands', 'updated_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

    // E. Ensure presence and privacy columns in 'users'
    await _ensureColumn(conn, dbName, 'users', 'is_online', 'BOOLEAN DEFAULT FALSE');
    await _ensureColumn(conn, dbName, 'users', 'last_seen', 'DATETIME NULL');
    await _ensureColumn(conn, dbName, 'users', 'profile_visible', 'BOOLEAN DEFAULT TRUE');
    await _ensureColumn(conn, dbName, 'users', 'show_online_status', 'BOOLEAN DEFAULT TRUE');
    await _ensureColumn(conn, dbName, 'users', 'analytics_enabled', 'BOOLEAN DEFAULT FALSE');

    // FC. File Uploads (Missing table fix)
    await _ensureTable(conn, dbName, 'file_uploads', '''
      CREATE TABLE file_uploads (
          id INT AUTO_INCREMENT PRIMARY KEY,
          original_filename VARCHAR(255) NOT NULL,
          stored_filename VARCHAR(255) NOT NULL,
          file_path TEXT NOT NULL,
          file_size BIGINT NOT NULL,
          mime_type VARCHAR(100) NOT NULL,
          uploaded_by VARCHAR(50) NOT NULL,
          is_public BOOLEAN DEFAULT FALSE,
          is_completed BOOLEAN DEFAULT FALSE,
          download_count INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          expires_at TIMESTAMP NULL,
          INDEX idx_uploaded_by (uploaded_by),
          INDEX idx_expires_at (expires_at),
          INDEX idx_is_completed (is_completed)
      )
    ''');

    await _ensureColumn(conn, dbName, 'file_uploads', 'is_completed', 'BOOLEAN DEFAULT FALSE');

    // FD. Revoked Tokens
    await _ensureTable(conn, dbName, 'revoked_tokens', '''
      CREATE TABLE revoked_tokens (
          id INT AUTO_INCREMENT PRIMARY KEY,
          token_hash VARCHAR(64) NOT NULL UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_hash (token_hash)
      )
    ''');

    // F. Ensure 'notifications' table exists
    await _ensureTable(conn, dbName, 'notifications', '''
      CREATE TABLE notifications (
          id INT AUTO_INCREMENT PRIMARY KEY,
          user_id VARCHAR(50) NOT NULL,
          title VARCHAR(255) NOT NULL,
          message TEXT NOT NULL,
          type VARCHAR(50) NOT NULL,
          is_read BOOLEAN DEFAULT FALSE,
          timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          INDEX idx_user_id (user_id),
          INDEX idx_is_read (is_read)
      )
    ''');

    // G. Audit Log
    await _ensureTable(conn, dbName, 'audit_log', '''
      CREATE TABLE audit_log (
          id INT AUTO_INCREMENT PRIMARY KEY,
          user_id VARCHAR(50) NOT NULL,
          action VARCHAR(100) NOT NULL,
          details JSON,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          INDEX idx_user_id (user_id),
          INDEX idx_action (action)
      )
    ''');

    await _ensureColumn(conn, dbName, 'audit_log', 'created_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP');

    // H. Departements
    await _ensureTable(conn, dbName, 'departements', '''
      CREATE TABLE departements (
          id INT AUTO_INCREMENT PRIMARY KEY,
          nom VARCHAR(100) NOT NULL UNIQUE,
          budget_annuel DECIMAL(15, 2) DEFAULT 0.0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    ''');

    // HH. Postes (Positions)
    await _ensureTable(conn, dbName, 'postes', '''
      CREATE TABLE postes (
          id INT AUTO_INCREMENT PRIMARY KEY,
          nom VARCHAR(100) NOT NULL UNIQUE,
          description TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Check if postes is empty, if so, seed it
    final posteCountRes = await conn.execute('SELECT COUNT(*) as count FROM postes');
    final posteCount = int.tryParse(posteCountRes.rows.first.colByName('count').toString()) ?? 0;
    if (posteCount == 0) {
      print('Seeding default postes...');
      await conn.execute("INSERT IGNORE INTO postes (nom, description) VALUES ('Directeur', 'Responsable de la direction générale'), ('Manager de projet', 'Gère les projets'), ('Team Lead', 'Encadre une équipe technique'), ('Développeur', 'Développe des applications'), ('Designer', 'Crée les interfaces'), ('Responsable RH', 'Gère les ressources humaines'), ('Comptable', 'Gère la comptabilité'), ('Support technique', 'Assiste les utilisateurs')");
    }

    // I. Clients
    await _ensureTable(conn, dbName, 'clients', '''
      CREATE TABLE clients (
          id INT AUTO_INCREMENT PRIMARY KEY,
          nom VARCHAR(100),
          prenom VARCHAR(100),
          raison_sociale VARCHAR(200),
          email VARCHAR(150),
          telephone VARCHAR(20),
          type ENUM('Entreprise','Particulier'),
          score_credit INT DEFAULT 0
      )
    ''');

    // J. Projets
    await _ensureTable(conn, dbName, 'projets', '''
      CREATE TABLE projets (
          id INT AUTO_INCREMENT PRIMARY KEY,
          nom VARCHAR(150) NOT NULL,
          description TEXT,
          client_id INT,
          budget DECIMAL(15, 2),
          cout_estime DECIMAL(15, 2),
          date_debut DATE,
          date_fin_prevue DATE,
          priorite ENUM('Basse', 'Moyenne', 'Haute', 'Critique') DEFAULT 'Moyenne',
          statut ENUM('A venir', 'En cours', 'Terminé', 'Suspendu') DEFAULT 'A venir',
          FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL
      )
    ''');

    // K. Sprints
    await _ensureTable(conn, dbName, 'sprints', '''
      CREATE TABLE sprints (
          id INT AUTO_INCREMENT PRIMARY KEY,
          projet_id INT NOT NULL,
          nom VARCHAR(100) NOT NULL,
          date_debut DATE,
          date_fin DATE,
          objectif TEXT,
          FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE CASCADE
      )
    ''');

    // L. Taches
    await _ensureTable(conn, dbName, 'taches', '''
      CREATE TABLE taches (
          id INT AUTO_INCREMENT PRIMARY KEY,
          sprint_id INT NOT NULL,
          employee_id VARCHAR(50),
          titre VARCHAR(200) NOT NULL,
          description TEXT,
          estimation_heures INT DEFAULT 0,
          heures_reelles INT DEFAULT 0,
          statut ENUM('ToDo', 'In Progress', 'Review', 'Done') DEFAULT 'ToDo',
          priorite ENUM('Low', 'Medium', 'High') DEFAULT 'Medium',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (sprint_id) REFERENCES sprints(id) ON DELETE CASCADE,
          FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    // M. Project Members
    await _ensureTable(conn, dbName, 'projet_membres', '''
      CREATE TABLE projet_membres (
          id INT AUTO_INCREMENT PRIMARY KEY,
          projet_id INT NOT NULL,
          employee_id VARCHAR(50) NOT NULL,
          role VARCHAR(100),
          joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE CASCADE,
          FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
          UNIQUE KEY (projet_id, employee_id)
      )
    ''');

    // N. Conversations
    await _ensureTable(conn, dbName, 'conversations', '''
      CREATE TABLE conversations (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255),
          type ENUM('direct', 'group') NOT NULL DEFAULT 'group',
          avatar_url TEXT,
          created_by VARCHAR(50),
          is_archived BOOLEAN DEFAULT FALSE,
          last_message_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_created_by (created_by)
      )
    ''');

    // O. Conversation Members
    await _ensureTable(conn, dbName, 'conversation_members', '''
      CREATE TABLE conversation_members (
          id INT AUTO_INCREMENT PRIMARY KEY,
          conversation_id INT NOT NULL,
          user_id VARCHAR(50) NOT NULL,
          joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          left_at TIMESTAMP NULL,
          last_read_at TIMESTAMP NULL,
          history_cleared_at TIMESTAMP NULL,
          FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          UNIQUE KEY unique_conv_user (conversation_id, user_id)
      )
    ''');

    // P. Messages
    await _ensureTable(conn, dbName, 'messages', '''
      CREATE TABLE messages (
          id INT AUTO_INCREMENT PRIMARY KEY,
          conversation_id INT NOT NULL,
          sender_id VARCHAR(50) NOT NULL,
          content TEXT NOT NULL,
          type ENUM('text', 'image', 'video', 'file', 'voice', 'system') DEFAULT 'text',
          reply_to_id INT NULL,
          is_edited BOOLEAN DEFAULT FALSE,
          edited_at TIMESTAMP NULL,
          is_deleted BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
          FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (reply_to_id) REFERENCES messages(id) ON DELETE SET NULL,
          INDEX idx_conversation_id (conversation_id),
          INDEX idx_sender_id (sender_id)
      )
    ''');

    // Q. Message Attachments
    await _ensureTable(conn, dbName, 'message_attachments', '''
      CREATE TABLE message_attachments (
          id INT AUTO_INCREMENT PRIMARY KEY,
          message_id INT NOT NULL,
          filename VARCHAR(255) NOT NULL,
          original_filename VARCHAR(255) NOT NULL,
          file_path TEXT NOT NULL,
          file_size INT NOT NULL,
          mime_type VARCHAR(100),
          thumbnail_path TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
          INDEX idx_message_id (message_id)
      )
    ''');

    // R. Message Voice Messages
    await _ensureTable(conn, dbName, 'message_voice_messages', '''
      CREATE TABLE message_voice_messages (
          id INT AUTO_INCREMENT PRIMARY KEY,
          message_id INT NOT NULL,
          file_path TEXT NOT NULL,
          file_size INT,
          duration INT DEFAULT 0,
          waveform_data JSON,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
          INDEX idx_message_id (message_id)
      )
    ''');

    // S. Message Reads
    await _ensureTable(conn, dbName, 'message_reads', '''
      CREATE TABLE message_reads (
          message_id INT NOT NULL,
          user_id VARCHAR(50) NOT NULL,
          read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (message_id, user_id),
          FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // T. Typing Events
    await _ensureTable(conn, dbName, 'typing_events', '''
      CREATE TABLE typing_events (
          conversation_id INT NOT NULL,
          user_id VARCHAR(50) NOT NULL,
          is_typing BOOLEAN DEFAULT FALSE,
          last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (conversation_id, user_id),
          FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // TA. Message Idempotency (Missing table fix)
    await _ensureTable(conn, dbName, 'message_idempotency', '''
      CREATE TABLE message_idempotency (
          client_message_id VARCHAR(100) NOT NULL,
          conversation_id INT NOT NULL,
          server_message_id INT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (client_message_id, conversation_id),
          FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
          FOREIGN KEY (server_message_id) REFERENCES messages(id) ON DELETE CASCADE
      )
    ''');

    await _ensureColumn(conn, dbName, 'conversation_members', 'history_cleared_at', 'TIMESTAMP NULL');

    // U. Convert ID columns to VARCHAR(50) for UUID support (idempotent ALTER)
    final tablesToFix = ['users', 'conversations', 'conversation_members', 'messages', 'message_reads'];
    for (final table in tablesToFix) {
      final col = (table == 'users') ? 'id' : (table == 'conversations' ? 'created_by' : (table == 'messages' ? 'sender_id' : 'user_id'));
      await _fixIdColumnType(conn, dbName, table, col);
    }
    
    // V. Apply Audit Fixes
    await _applyAuditFixes(conn, dbName);
  }

  static Future<void> _applyAuditFixes(_DBProxy conn, String dbName) async {
    print('Checking and applying Architectural Audit Fixes...');
    
    // 1. Soft Delete Flags
    await _ensureColumn(conn, dbName, 'users', 'is_deleted', 'BOOLEAN DEFAULT FALSE');
    await _ensureColumn(conn, dbName, 'employees', 'is_deleted', 'BOOLEAN DEFAULT FALSE');
    await _ensureColumn(conn, dbName, 'projets', 'is_deleted', 'BOOLEAN DEFAULT FALSE');
    await _ensureColumn(conn, dbName, 'taches', 'is_deleted', 'BOOLEAN DEFAULT FALSE');

    // Remove CASCADE deletes from core tables (employees -> user, projet_membres -> user, etc)
    // We can run safe alters to drop the constraint then re-add it as RESTRICT, but that requires finding constraint names.
    // So we'll run a custom script for employees and users to ensure they aren't CASCADE.
    await _replaceCascadeWithRestrict(conn, dbName, 'employees');
    await _replaceCascadeWithRestrict(conn, dbName, 'projet_membres');
    await _replaceCascadeWithRestrict(conn, dbName, 'taches');
    await _replaceCascadeWithRestrict(conn, dbName, 'projets');
    
    // 2. Enforced Foreign Keys for Employees (Departement & Poste)
    await _ensureColumn(conn, dbName, 'employees', 'departement_id', 'INT NULL');
    await _ensureColumn(conn, dbName, 'employees', 'poste_id', 'INT NULL');
    await _ensureForeignKey(conn, dbName, 'employees', 'fk_emp_dept', 'departement_id', 'departements', 'id', 'ON DELETE SET NULL');
    await _ensureForeignKey(conn, dbName, 'employees', 'fk_emp_poste', 'poste_id', 'postes', 'id', 'ON DELETE SET NULL');

    // 3. Enforced Foreign Key for Demands -> Handled By
    await _ensureForeignKey(conn, dbName, 'demands', 'fk_demands_handler', 'handled_by', 'users', 'id', 'ON DELETE SET NULL');

    // 4. Audit Trail Triggers
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_audit_salaries_update');
      await conn.execute('''
        CREATE TRIGGER trg_audit_salaries_update
        AFTER UPDATE ON salaries
        FOR EACH ROW
        BEGIN
            IF OLD.base_salary != NEW.base_salary OR OLD.net_salary != NEW.net_salary THEN
                INSERT INTO audit_log (user_id, action, details)
                VALUES (NEW.employee_id, 'SALARY_UPDATED', JSON_OBJECT('old_base', OLD.base_salary, 'new_base', NEW.base_salary));
            END IF;
        END
      ''');
    } catch(e) { print('Salary trigger info: $e'); }

    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_audit_bonuses_insert');
      await conn.execute('''
        CREATE TRIGGER trg_audit_bonuses_insert
        AFTER INSERT ON bonuses
        FOR EACH ROW
        BEGIN
            INSERT INTO audit_log (user_id, action, details)
            VALUES (NEW.employee_id, 'BONUS_GRANTED', JSON_OBJECT('amount', NEW.amount, 'type', NEW.bonus_type));
        END
      ''');
    } catch(e) { print('Bonus trigger info: $e'); }

    // 5. Clean up expired tokens (Immediate cleanup during startup)
    // 6. Expense Approval & Multi-level chain
    await _ensureColumn(conn, dbName, 'depenses_projets', 'status', "ENUM('pending', 'approved_manager', 'approved_hr', 'approved_finance', 'rejected') DEFAULT 'pending'");
    await _ensureColumn(conn, dbName, 'depenses_entreprise', 'status', "ENUM('pending', 'approved_manager', 'approved_hr', 'approved_finance', 'rejected') DEFAULT 'pending'");
    await _ensureColumn(conn, dbName, 'depenses_projets', 'manager_id', 'VARCHAR(50) NULL');
    await _ensureColumn(conn, dbName, 'depenses_projets', 'hr_id', 'VARCHAR(50) NULL');
    await _ensureColumn(conn, dbName, 'depenses_projets', 'finance_id', 'VARCHAR(50) NULL');
    await _ensureColumn(conn, dbName, 'depenses_entreprise', 'manager_id', 'VARCHAR(50) NULL');
    await _ensureColumn(conn, dbName, 'depenses_entreprise', 'hr_id', 'VARCHAR(50) NULL');
    await _ensureColumn(conn, dbName, 'depenses_entreprise', 'finance_id', 'VARCHAR(50) NULL');

    // 7. Audit log for project deletion (Safety Trigger)
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_audit_projets_delete');
      await conn.execute('''
        CREATE TRIGGER trg_audit_projets_delete
        AFTER UPDATE ON projets
        FOR EACH ROW
        BEGIN
            IF OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
                INSERT INTO audit_log (user_id, action, details)
                VALUES ('SYSTEM', 'PROJECT_DELETED_SOFT', JSON_OBJECT('id', OLD.id, 'name', OLD.nom));
            END IF;
        END
      ''');
    } catch(e) {}
  }

  static Future<void> _replaceCascadeWithRestrict(_DBProxy conn, String dbName, String tableName) async {
    final constraintsReq = await conn.execute(
      '''
      SELECT CONSTRAINT_NAME, REFERENCED_TABLE_NAME 
      FROM information_schema.REFERENTIAL_CONSTRAINTS 
      WHERE CONSTRAINT_SCHEMA = :db AND TABLE_NAME = :table AND DELETE_RULE = 'CASCADE'
      ''',
      {'db': dbName, 'table': tableName},
    );
    
    for (var row in constraintsReq.rows) {
      final constraintName = row.colAt(0).toString();
      final refTable = row.colAt(1).toString();
      
      final cols = await conn.execute(
         "SELECT COLUMN_NAME, REFERENCED_COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_NAME = :cname AND TABLE_SCHEMA = :db",
         {'cname': constraintName, 'db': dbName}
      );
      
      if (cols.rows.isNotEmpty) {
        final colName = cols.rows.first.colByName('COLUMN_NAME').toString();
        final refColName = cols.rows.first.colByName('REFERENCED_COLUMN_NAME').toString();
        
        print('Patching CASCADE constraint $constraintName on $tableName...');
        try {
           await conn.execute("ALTER TABLE $tableName DROP FOREIGN KEY $constraintName");
           
           // If it's something like employees.user_id, we might want NO ACTION. Let's use RESTRICT.
           await conn.execute("ALTER TABLE $tableName ADD CONSTRAINT $constraintName FOREIGN KEY ($colName) REFERENCES $refTable($refColName) ON DELETE RESTRICT");
        } catch (e) {
           print('Failed to patch constraint $constraintName: $e');
        }
      }
    }
  }

  static Future<void> _ensureForeignKey(_DBProxy conn, String dbName, String tableName, String constraintName, String column, String refTable, String refColumn, String rule) async {
    final check = await conn.execute(
      "SELECT COUNT(*) as cnt FROM information_schema.table_constraints WHERE table_schema = :db AND table_name = :table AND constraint_name = :cname",
      {'db': dbName, 'table': tableName, 'cname': constraintName},
    );
    if ((int.tryParse(check.rows.first.colByName('cnt').toString()) ?? 0) == 0) {
      print('Adding foreign key $constraintName to $tableName');
      try {
        await conn.execute("ALTER TABLE $tableName ADD CONSTRAINT $constraintName FOREIGN KEY ($column) REFERENCES $refTable($refColumn) $rule");
      } catch (e) {
        print('Skipping FK addition due to missing target table or column: $e');
      }
    }
  }

  static Future<void> _ensureTable(_DBProxy conn, String dbName, String tableName, String createSql) async {
    final check = await conn.execute(
      "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = :table",
      {'db': dbName, 'table': tableName},
    );
    if ((int.tryParse(check.rows.first.colByName('cnt').toString()) ?? 0) == 0) {
      print('Creating table: $tableName');
      await conn.execute(createSql);
    }
  }

  static Future<void> _ensureColumn(_DBProxy conn, String dbName, String tableName, String columnName, String definition) async {
    final check = await conn.execute(
      "SELECT COUNT(*) as cnt FROM information_schema.columns WHERE table_schema = :db AND table_name = :table AND column_name = :col",
      {'db': dbName, 'table': tableName, 'col': columnName},
    );
    if ((int.tryParse(check.rows.first.colByName('cnt').toString()) ?? 0) == 0) {
      print('Adding column $columnName to $tableName');
      await conn.execute("ALTER TABLE $tableName ADD COLUMN $columnName $definition");
    }
  }

  static Future<void> _fixIdColumnType(_DBProxy conn, String dbName, String tableName, String columnName) async {
    final check = await conn.execute(
      "SELECT DATA_TYPE FROM information_schema.columns WHERE table_schema = :db AND table_name = :table AND column_name = :col",
      {'db': dbName, 'table': tableName, 'col': columnName},
    );
    if (check.rows.isNotEmpty && check.rows.first.colAt(0).toString().toLowerCase().contains('int')) {
      print('Migrating $tableName.$columnName to VARCHAR(50)');
      await conn.execute('SET FOREIGN_KEY_CHECKS = 0');
      try {
        await conn.execute('ALTER TABLE $tableName MODIFY $columnName VARCHAR(50) NOT NULL');
      } finally {
        await conn.execute('SET FOREIGN_KEY_CHECKS = 1');
      }
    }
  }

  /// Seeds new granular permissions that older databases may be missing.
  /// Safe to run multiple times — uses INSERT IGNORE.
  static Future<void> _seedMissingPermissions(_DBProxy conn) async {
    print('Seeding missing permissions into database...');
    final newPermissions = [
      // Employees self-service HR permissions
      {'nom': 'log_own_attendance', 'module': 'HR', 'description': 'Enregistrer sa propre présence (check-in/check-out)'},
      {'nom': 'submit_leave', 'module': 'HR', 'description': 'Soumettre une demande de congé'},
      {'nom': 'submit_remote_work', 'module': 'HR', 'description': 'Soumettre une demande de télétravail'},
      // Finance split
      {'nom': 'view_finances', 'module': 'Finance', 'description': 'Consulter les données financières'},
      {'nom': 'manage_finance', 'module': 'Finance', 'description': 'Gérer les opérations financières'},
    ];

    for (final perm in newPermissions) {
      try {
        await conn.execute(
          "INSERT IGNORE INTO permissions (nom, module, description) VALUES (:nom, :module, :description)",
          perm,
        );
      } catch (e) {
        print('Permission seed warning [${perm['nom']}]: $e');
      }
    }

    // Auto-assign ALL permissions to Admin role
    try {
      await conn.execute('''
        INSERT IGNORE INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id FROM roles r, permissions p WHERE r.nom = 'Admin'
      ''');
    } catch (e) {
      print('Admin role permission re-sync error: $e');
    }

    // Auto-assign employee self-service permissions to "Employé" role
    try {
      await conn.execute('''
        INSERT IGNORE INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id FROM roles r, permissions p
        WHERE r.nom = 'Employé' AND p.nom IN (
          'log_own_attendance', 'submit_leave', 'submit_remote_work',
          'view_tasks', 'execute_tasks', 'update_task_progress',
          'send_messages', 'view_messages', 'view_projects'
        )
      ''');
    } catch (e) {
      print('Employé permission auto-assignment error: $e');
    }

    print('Permission seeding complete.');
  }
}

// Helper typedef as _DBProxy is private to connection.dart but often needed for type safety in Migrations
// Actually in connection.dart _DBProxy is private. We should probably make it public or just use dynamic.
// I'll use dynamic in parameters for simplicity or rename it in connection.dart.
// Let's use dynamic for now.
typedef _DBProxy = dynamic;