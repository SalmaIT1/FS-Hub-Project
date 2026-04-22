import 'dart:io';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'connection.dart';
import 'seeder.dart';

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
        print('Initial schema not found. Applying backend/lib/database/schema.sql...');
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

      // 3b. Seed missing permissions and system data
      await _seedMissingPermissions(conn);
      await DatabaseSeeder.seed(conn);
      
      // 4. Reset all users to offline on startup (in case of previous crash)
      print('Resetting user presence states...');
      await conn.execute('UPDATE users SET is_online = FALSE');

      print('Database initialization complete.');
    } catch (e, stack) {
      print('CRITICAL: Database initialization failed: $e\n$stack');
    }
  }

  static Future<void> _runIncrementalMigrations(DBProxy conn, String dbName) async {
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

    // FB-FIX: user_roles.assigned_at — required by employee creation RBAC insert
    await _ensureColumn(conn, dbName, 'user_roles', 'assigned_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP');

    // FB-FIX2: users.is_active — required by deactivate-employee soft-delete query
    await _ensureColumn(conn, dbName, 'users', 'is_active', 'TINYINT(1) DEFAULT 1');

    // HR-FIX: Add base_salary to employees for payroll defaults
    await _ensureColumn(conn, dbName, 'employees', 'base_salary', 'DECIMAL(12,2) DEFAULT 0.00');

    // FD. Revoked Tokens
    await _ensureTable(conn, dbName, 'revoked_tokens', '''
      CREATE TABLE revoked_tokens (
          id INT AUTO_INCREMENT PRIMARY KEY,
          token_hash VARCHAR(64) NOT NULL UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_hash (token_hash)
      )
    ''');

    // FE. Rate Limit Attempts (H-4/H-5 FIX: DB-backed rate limiter)
    await _ensureTable(conn, dbName, 'rate_limit_attempts', '''
      CREATE TABLE rate_limit_attempts (
          id INT AUTO_INCREMENT PRIMARY KEY,
          endpoint VARCHAR(100) NOT NULL,
          ip_address VARCHAR(45) NOT NULL,
          attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_endpoint_ip (endpoint, ip_address),
          INDEX idx_attempted_at (attempted_at)
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

    // HARSH FIX: Password Resets (Secure reset tokens)
    await _ensureTable(conn, dbName, 'password_resets', '''
      CREATE TABLE IF NOT EXISTS password_resets (
          id INT AUTO_INCREMENT PRIMARY KEY,
          user_id VARCHAR(50) NOT NULL,
          token_hash VARCHAR(64) NOT NULL,
          is_used BOOLEAN DEFAULT FALSE,
          expires_at TIMESTAMP NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          INDEX idx_token (token_hash),
          INDEX idx_user_expires (user_id, expires_at)
      )
    ''');

    // HR MODULE TABLES
    await _ensureTable(conn, dbName, 'salaries', '''
      CREATE TABLE IF NOT EXISTS salaries (
          id INT PRIMARY KEY AUTO_INCREMENT,
          employee_id VARCHAR(50) NOT NULL,
          base_salary DECIMAL(12,2) NOT NULL,
          bonus_amount DECIMAL(12,2) DEFAULT 0,
          deductions DECIMAL(12,2) DEFAULT 0,
          net_salary DECIMAL(12,2),
          salary_month DATE NOT NULL,
          payment_status ENUM('pending', 'paid', 'cancelled') DEFAULT 'pending',
          paid_at DATETIME,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
          UNIQUE(employee_id, salary_month)
      )
    ''');

    await _ensureTable(conn, dbName, 'bonuses', '''
      CREATE TABLE IF NOT EXISTS bonuses (
          id INT PRIMARY KEY AUTO_INCREMENT,
          employee_id VARCHAR(50) NOT NULL,
          amount DECIMAL(12,2) NOT NULL,
          reason VARCHAR(255),
          bonus_type ENUM('performance', 'project_completion', 'holiday', 'referral', 'other') DEFAULT 'performance',
          granted_by VARCHAR(50),
          granted_date DATE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
          FOREIGN KEY (granted_by) REFERENCES users(id)
      )
    ''');

    // FINANCE TABLES
    await _ensureTable(conn, dbName, 'expense_categories', '''
      CREATE TABLE IF NOT EXISTS expense_categories (
          id INT AUTO_INCREMENT PRIMARY KEY,
          nom VARCHAR(100) NOT NULL UNIQUE,
          description TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await _ensureTable(conn, dbName, 'depenses_projets', '''
      CREATE TABLE IF NOT EXISTS depenses_projets (
          id INT AUTO_INCREMENT PRIMARY KEY,
          montant DECIMAL(15, 2) NOT NULL,
          date_depense DATE NOT NULL,
          description TEXT,
          projet_id INT NOT NULL,
          category_id INT,
          created_by VARCHAR(50),
          status ENUM('pending', 'approved_manager', 'approved_hr', 'approved_finance', 'rejected') DEFAULT 'pending',
          manager_id VARCHAR(50) NULL,
          hr_id VARCHAR(50) NULL,
          finance_id VARCHAR(50) NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE CASCADE,
          FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL,
          FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    await _ensureTable(conn, dbName, 'depenses_entreprise', '''
      CREATE TABLE IF NOT EXISTS depenses_entreprise (
          id INT AUTO_INCREMENT PRIMARY KEY,
          montant DECIMAL(15, 2) NOT NULL,
          date_depense DATE NOT NULL,
          description TEXT,
          category_id INT,
          created_by VARCHAR(50),
          status ENUM('pending', 'approved_manager', 'approved_hr', 'approved_finance', 'rejected') DEFAULT 'pending',
          manager_id VARCHAR(50) NULL,
          hr_id VARCHAR(50) NULL,
          finance_id VARCHAR(50) NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL,
          FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
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
          score_credit INT DEFAULT 0,
          solde_du DECIMAL(15,2) DEFAULT 0.00
      )
    ''');

    await _ensureColumn(conn, dbName, 'clients', 'user_id', 'VARCHAR(50) UNIQUE NULL');
    await _ensureForeignKey(conn, dbName, 'clients', 'fk_client_user', 'user_id', 'users', 'id', 'ON DELETE SET NULL');
    await _ensureColumn(conn, dbName, 'clients', 'matricule_fiscale', 'VARCHAR(100) NULL');
    await _ensureColumn(conn, dbName, 'clients', 'adresse', 'TEXT NULL');
    await _ensureColumn(conn, dbName, 'clients', 'patente_document', 'TEXT NULL');
    await _ensureColumn(conn, dbName, 'clients', 'solde_du', 'DECIMAL(15,2) DEFAULT 0.00');
    // P2 FIX: Data migration from legacy 'credit' column if it exists and has content
    try {
      await conn.execute("UPDATE clients SET solde_du = credit WHERE credit > 0 AND solde_du = 0");
    } catch (_) {}

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

    await _ensureColumn(conn, dbName, 'projets', 'contract_url', "VARCHAR(500) NULL COMMENT 'Relative path to the uploaded contract file'");
    await _ensureColumn(conn, dbName, 'projets', 'contract_filename', "VARCHAR(255) NULL COMMENT 'Original filename of the uploaded contract'");
    await _ensureColumn(conn, dbName, 'projets', 'contract_uploaded_at', "DATETIME NULL COMMENT 'Timestamp when the contract was uploaded'");

    // J.1 Devis
    await _ensureTable(conn, dbName, 'devis', '''
      CREATE TABLE devis (
          id INT AUTO_INCREMENT PRIMARY KEY,
          projet_id INT NULL,
          client_id INT NOT NULL,
          numero_devis VARCHAR(50) NOT NULL UNIQUE,
          montant_ht DECIMAL(15, 2) DEFAULT 0.0,
          tva DECIMAL(5, 2) DEFAULT 0.0,
          montant_ttc DECIMAL(15, 2) DEFAULT 0.0,
          date_emission DATE,
          date_validite DATE,
          statut ENUM('Brouillon', 'Envoyé', 'Accepté', 'Refusé') DEFAULT 'Brouillon',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE SET NULL,
          FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
      )
    ''');

    // J.2 Factures
    await _ensureTable(conn, dbName, 'factures', '''
      CREATE TABLE factures (
          id INT AUTO_INCREMENT PRIMARY KEY,
          projet_id INT NULL,
          client_id INT NOT NULL,
          numero_facture VARCHAR(50) NOT NULL UNIQUE,
          montant_ht DECIMAL(15, 2) DEFAULT 0.0,
          tva DECIMAL(5, 2) DEFAULT 0.0,
          montant_ttc DECIMAL(15, 2) DEFAULT 0.0,
          date_emission DATE,
          date_echeance DATE,
          statut ENUM('Brouillon', 'Envoyée', 'Payée', 'Partiellement payée', 'En retard', 'Annulée') DEFAULT 'Brouillon',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE SET NULL,
          FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
      )
    ''');

    // FIX: Ensure 'Partiellement payée' is present in the ENUM even for existing databases
    try {
      await conn.execute("ALTER TABLE factures MODIFY statut ENUM('Brouillon', 'Envoyée', 'Payée', 'Partiellement payée', 'En retard', 'Annulée') DEFAULT 'Brouillon'");
    } catch (_) {}

    await _ensureColumn(conn, dbName, 'factures', 'devis_id', 'INT NULL');
    await _ensureForeignKey(conn, dbName, 'factures', 'fk_facture_devis', 'devis_id', 'devis', 'id', 'ON DELETE SET NULL');

    // Quote Approval Trigger
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_check_quote_approved');
      await conn.execute('''
        CREATE TRIGGER trg_check_quote_approved
        BEFORE INSERT ON factures
        FOR EACH ROW
        BEGIN
            DECLARE q_status VARCHAR(50);
            IF NEW.devis_id IS NOT NULL THEN
                SELECT statut INTO q_status FROM devis WHERE id = NEW.devis_id;
                IF q_status != 'Approuve' AND q_status != 'Accepté' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot create invoice: associated quote is not approved';
                END IF;
            END IF;
        END
      ''');
    } catch(e) {}

    // J.3 Paiements
    await _ensureTable(conn, dbName, 'paiements', '''
      CREATE TABLE paiements (
          id INT AUTO_INCREMENT PRIMARY KEY,
          facture_id INT NOT NULL,
          montant DECIMAL(15, 2) NOT NULL,
          mode VARCHAR(50),
          date_paiement DATE,
          reference_transaction VARCHAR(255),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (facture_id) REFERENCES factures(id) ON DELETE CASCADE
      )
    ''');

    await _ensureColumn(conn, dbName, 'paiements', 'client_request_id', 'VARCHAR(100) NULL');
    await _ensureColumn(conn, dbName, 'paiements', 'client_id', 'INT NULL');
    await _ensureForeignKey(conn, dbName, 'paiements', 'fk_paiement_client', 'client_id', 'clients', 'id', 'ON DELETE SET NULL');
    try {
      await conn.execute('ALTER TABLE paiements ADD UNIQUE INDEX idx_unique_payment_request (client_request_id)');
    } catch (_) {}

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

    // P0-02 FIX: Unread Badge Synchronisation Trigger
    // Automatically updates conversation_members.last_read_at when an individual 
    // message is marked as read via the ACK protocol, ensuring the conversation 
    // unread count (calculated using last_read_at) stays accurate.
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_message_reads_sync_conv');
      await conn.execute('''
        CREATE TRIGGER trg_message_reads_sync_conv
        AFTER INSERT ON message_reads
        FOR EACH ROW
        BEGIN
            DECLARE msg_created_at TIMESTAMP;
            DECLARE msg_conv_id INT;
            
            -- Get the creation date and conversation ID of the read message
            SELECT created_at, conversation_id INTO msg_created_at, msg_conv_id 
            FROM messages WHERE id = NEW.message_id;
            
            -- Update conversation_members.last_read_at only if the read message 
            -- is newer than the current last_read_at value.
            UPDATE conversation_members 
            SET last_read_at = msg_created_at 
            WHERE conversation_id = msg_conv_id 
            AND user_id = NEW.user_id
            AND (last_read_at IS NULL OR last_read_at < msg_created_at);
        END
      ''');
    } catch(e) {}

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
    final tablesToFix = {
      'users': 'id',
      'conversations': 'created_by',
      'conversation_members': 'user_id',
      'messages': 'sender_id',
      'message_reads': 'user_id',
      'file_uploads': 'uploaded_by',
      'notifications': 'user_id',
      'audit_log': 'user_id',
      'demands': 'requester_id',
      'employees': 'user_id',
      'depenses_projets': 'created_by',
      'depenses_entreprise': 'created_by',
    };

    for (final entry in tablesToFix.entries) {
      await _fixIdColumnType(conn, dbName, entry.key, entry.value);
    }
    
    // V. Apply Audit Fixes
    await _applyAuditFixes(conn, dbName);

    // W. Ensure reserved SYSTEM user exists for system chat messages
    print('Ensuring SYSTEM user exists...');
    await conn.execute(
      "INSERT INTO users (id, username, password, role, is_active) VALUES ('00000000-0000-0000-0000-000000000000', 'SYSTEM', 'SYSTEM_LOCKED', 'Admin', 1) ON DUPLICATE KEY UPDATE username = 'SYSTEM', is_active = 1",
    );
  }

  static Future<void> _applyAuditFixes(DBProxy conn, String dbName) async {
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
    
    // 8. Financial Integrity: solde_du (debt) and Payment Sync
    // Trigger on factures to increase client debt
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_facture_ins_balance');
      await conn.execute('''
        CREATE TRIGGER trg_facture_ins_balance
        AFTER INSERT ON factures
        FOR EACH ROW
        BEGIN
            -- Only increase balance if invoice is NOT a draft or cancelled
            IF NEW.statut NOT IN ('Brouillon', 'Annulée') THEN
                UPDATE clients SET solde_du = solde_du + NEW.montant_ttc WHERE id = NEW.client_id;
            END IF;
        END
      ''');
    } catch(e) {}

    // Trigger on factures to handle status/amount updates (P0 Fix)
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_facture_upd_balance');
      await conn.execute('''
        CREATE TRIGGER trg_facture_upd_balance
        AFTER UPDATE ON factures
        FOR EACH ROW
        BEGIN
            DECLARE old_active BOOLEAN;
            DECLARE new_active BOOLEAN;
            
            SET old_active = OLD.statut NOT IN ('Brouillon', 'Annulée');
            SET new_active = NEW.statut NOT IN ('Brouillon', 'Annulée');
            
            IF old_active AND new_active THEN
                -- Amount changed while active: update difference
                UPDATE clients SET solde_du = solde_du + (NEW.montant_ttc - OLD.montant_ttc) WHERE id = NEW.client_id;
            ELSEIF NOT old_active AND new_active THEN
                -- Became active (e.g. Draft -> Sent): add full amount
                UPDATE clients SET solde_du = solde_du + NEW.montant_ttc WHERE id = NEW.client_id;
            ELSEIF old_active AND NOT new_active THEN
                -- Became inactive (e.g. Sent -> Cancelled): subtract full amount
                UPDATE clients SET solde_du = solde_du - OLD.montant_ttc WHERE id = NEW.client_id;
            END IF;
            
            -- If client_id changed (rare but possible), this trigger would need more logic. 
            -- Assuming client_id is immutable for this audit scope.
        END
      ''');
    } catch(e) {}

    // Trigger on factures to decrease client debt on deletion
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_facture_del_balance');
      await conn.execute('''
        CREATE TRIGGER trg_facture_del_balance
        AFTER DELETE ON factures
        FOR EACH ROW
        BEGIN
            -- Only decrease balance if invoice was active
            IF OLD.statut NOT IN ('Brouillon', 'Annulée') THEN
                UPDATE clients SET solde_du = solde_du - OLD.montant_ttc WHERE id = OLD.client_id;
            END IF;
        END
      ''');
    } catch(e) {}

    // Trigger on paiements to decrease client debt and sync invoice status
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_paiement_ins_sync');
      await conn.execute('''
        CREATE TRIGGER trg_paiement_ins_sync
        AFTER INSERT ON paiements
        FOR EACH ROW
        BEGIN
            DECLARE total_paid DECIMAL(15, 2);
            DECLARE total_ttc DECIMAL(15, 2);
            DECLARE c_id INT;
            
            SET c_id = NEW.client_id;
            SELECT montant_ttc INTO total_ttc FROM factures WHERE id = NEW.facture_id;
            
            IF c_id IS NULL THEN
                SELECT client_id INTO c_id FROM factures WHERE id = NEW.facture_id;
            END IF;
            
            -- Update client balance (decrease debt)
            IF c_id IS NOT NULL THEN
                UPDATE clients SET solde_du = solde_du - NEW.montant WHERE id = c_id;
            END IF;
            
            -- Check if invoice is now fully paid
            SELECT SUM(montant) INTO total_paid FROM paiements WHERE facture_id = NEW.facture_id;
            IF total_paid >= total_ttc THEN
                UPDATE factures SET statut = 'Payée' WHERE id = NEW.facture_id;
            ELSEIF total_paid > 0 THEN
                UPDATE factures SET statut = 'Partiellement payée' WHERE id = NEW.facture_id;
            END IF;
        END
      ''');
    } catch(e) {}

    // Trigger on paiements to increase client debt on payment deletion and revert invoice status
    try {
      await conn.execute('DROP TRIGGER IF EXISTS trg_paiement_del_sync');
      await conn.execute('''
        CREATE TRIGGER trg_paiement_del_sync
        AFTER DELETE ON paiements
        FOR EACH ROW
        BEGIN
            DECLARE total_paid DECIMAL(15, 2);
            DECLARE total_ttc DECIMAL(15, 2);
            DECLARE c_id INT;
            
            SET c_id = OLD.client_id;
            SELECT montant_ttc INTO total_ttc FROM factures WHERE id = OLD.facture_id;
            
            IF total_ttc IS NULL THEN
                -- Factures was deleted (cascade delete case). Update client explicitly.
                IF c_id IS NOT NULL THEN
                    UPDATE clients SET solde_du = solde_du + OLD.montant WHERE id = c_id;
                END IF;
            ELSE
                -- Normal deletion
                IF c_id IS NULL THEN
                    SELECT client_id INTO c_id FROM factures WHERE id = OLD.facture_id;
                END IF;
                
                IF c_id IS NOT NULL THEN
                    UPDATE clients SET solde_du = solde_du + OLD.montant WHERE id = c_id;
                END IF;
                
                -- Revert invoice status if no longer fully paid
                SELECT COALESCE(SUM(montant), 0) INTO total_paid FROM paiements WHERE facture_id = OLD.facture_id;
                IF total_paid <= 0 THEN
                    UPDATE factures SET statut = 'Envoyée' WHERE id = OLD.facture_id;
                ELSEIF total_paid < total_ttc THEN
                    UPDATE factures SET statut = 'Partiellement payée' WHERE id = OLD.facture_id;
                END IF;
            END IF;
        END
      ''');
    } catch(e) {}

    // ── FIX DOUBLONS ET UNICITÉ (FORCE MODE) ──────────────────────────────
    print('[DB-FIX] Starting emergency cleanup of duplicate roles/permissions...');
    try {
      await conn.execute('SET FOREIGN_KEY_CHECKS = 0');
      
      // Nettoyer les rôles
      await conn.execute('''
        DELETE FROM roles WHERE id NOT IN (
          SELECT id FROM (SELECT MIN(id) as id FROM roles GROUP BY nom) as rtmp
        )
      ''');
      
      // Nettoyer les permissions
      await conn.execute('''
        DELETE FROM permissions WHERE id NOT IN (
          SELECT id FROM (SELECT MIN(id) as id FROM permissions GROUP BY nom) as ptmp
        )
      ''');

      await conn.execute('SET FOREIGN_KEY_CHECKS = 1');
      
      // Ajouter les contraintes d'unicité (SI elles n'existent pas encore)
      try { await conn.execute('ALTER TABLE roles ADD UNIQUE INDEX idx_unique_role_nom (nom)'); } catch(_) {}
      try { await conn.execute('ALTER TABLE permissions ADD UNIQUE INDEX idx_unique_perm_nom (nom)'); } catch(_) {}
      
      // ── FUSION ET NORMALISATION DES PERMISSIONS ─────────────────────────
      print('[DB-FIX] Merging duplicate permission notations...');
      final normalizationMapping = {
        'employees.view': 'view_employees',
        'employees.manage': 'manage_employees',
        'salaries.view': 'manage_salaries',
        'salaries.manage': 'manage_salaries',
        'leave.manage': 'manage_leaves',
        'attendance.manage': 'manage_attendance',
        'remote_work.manage': 'manage_remote_work'
      };

      for (var entry in normalizationMapping.entries) {
        final oldNom = entry.key;
        final newNom = entry.value;

        // 1. Get IDs
        final oldRes = await conn.execute('SELECT id FROM permissions WHERE nom = :n', {'n': oldNom});
        final newRes = await conn.execute('SELECT id FROM permissions WHERE nom = :n', {'n': newNom});

        if (oldRes.rows.isNotEmpty && newRes.rows.isNotEmpty) {
           final oldId = oldRes.rows.first.colAt(0).toString();
           final newId = newRes.rows.first.colAt(0).toString();

           // 2. Transfer role links from old to new (IGNORE duplicates)
           await conn.execute('UPDATE IGNORE role_permissions SET permission_id = :newId WHERE permission_id = :oldId', {'newId': newId, 'oldId': oldId});
           
           // 3. Delete old dot-notation permission
           await conn.execute('DELETE FROM role_permissions WHERE permission_id = :oldId', {'oldId': oldId});
           await conn.execute('DELETE FROM permissions WHERE id = :oldId', {'oldId': oldId});
        } else if (oldRes.rows.isNotEmpty) {
           // Only old one exists, just rename it
           await conn.execute('UPDATE permissions SET nom = :newNom WHERE nom = :oldNom', {'newNom': newNom, 'oldNom': oldNom});
        }
      }
      
      print('[DB-FIX] Cleanup successful. Nomenclature normalized.');
    } catch (e) {
      print('[DB-FIX] ERROR during cleanup: $e');
      await conn.execute('SET FOREIGN_KEY_CHECKS = 1');
    }
  }

  static Future<void> _replaceCascadeWithRestrict(DBProxy conn, String dbName, String tableName) async {
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

  static Future<void> _ensureForeignKey(DBProxy conn, String dbName, String tableName, String constraintName, String column, String refTable, String refColumn, String rule) async {
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

  static Future<void> _ensureTable(DBProxy conn, String dbName, String tableName, String createSql) async {
    final check = await conn.execute(
      "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = :table",
      {'db': dbName, 'table': tableName},
    );
    if ((int.tryParse(check.rows.first.colByName('cnt').toString()) ?? 0) == 0) {
      print('Creating table: $tableName');
      await conn.execute(createSql);
    }
  }

  static Future<void> _ensureColumn(DBProxy conn, String dbName, String tableName, String columnName, String definition) async {
    final check = await conn.execute(
      "SELECT COUNT(*) as cnt FROM information_schema.columns WHERE table_schema = :db AND table_name = :table AND column_name = :col",
      {'db': dbName, 'table': tableName, 'col': columnName},
    );
    if ((int.tryParse(check.rows.first.colByName('cnt').toString()) ?? 0) == 0) {
      print('Adding column $columnName to $tableName');
      await conn.execute("ALTER TABLE $tableName ADD COLUMN $columnName $definition");
    }
  }

  static Future<void> _fixIdColumnType(DBProxy conn, String dbName, String tableName, String columnName) async {
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
  static Future<void> _seedMissingPermissions(DBProxy conn) async {
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

    // Auto-assign HR permissions to "RH" role
    try {
      await conn.execute('''
        INSERT IGNORE INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id FROM roles r, permissions p
        WHERE (r.nom = 'RH' OR r.nom = 'Human Resources') AND p.module = 'HR'
      ''');
    } catch (e) {
      print('RH permission auto-assignment error: $e');
    }

    print('Permission seeding complete.');
  }
}
