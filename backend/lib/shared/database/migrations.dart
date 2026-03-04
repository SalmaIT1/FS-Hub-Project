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

    // E. Ensure presence columns in 'users'
    await _ensureColumn(conn, dbName, 'users', 'is_online', 'BOOLEAN DEFAULT FALSE');
    await _ensureColumn(conn, dbName, 'users', 'last_seen', 'DATETIME NULL');

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

    await _ensureColumn(conn, dbName, 'conversation_members', 'history_cleared_at', 'TIMESTAMP NULL');

    // U. Convert ID columns to VARCHAR(50) for UUID support (idempotent ALTER)
    final tablesToFix = ['users', 'conversations', 'conversation_members', 'messages', 'message_reads'];
    for (final table in tablesToFix) {
      final col = (table == 'users') ? 'id' : (table == 'conversations' ? 'created_by' : (table == 'messages' ? 'sender_id' : 'user_id'));
      await _fixIdColumnType(conn, dbName, table, col);
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
}

// Helper typedef as _DBProxy is private to connection.dart but often needed for type safety in Migrations
// Actually in connection.dart _DBProxy is private. We should probably make it public or just use dynamic.
// I'll use dynamic in parameters for simplicity or rename it in connection.dart.
// Let's use dynamic for now.
typedef _DBProxy = dynamic;