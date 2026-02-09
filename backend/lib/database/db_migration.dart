import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'db_connection.dart';

class DBMigration {
  static Future<void> runMigrations() async {
    try {
      final conn = DBConnection.getConnection();

      // If the users table already exists, assume migrations were applied.
      try {
        final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
        final dbName = env['DB_NAME'] ?? 'fs_hub_db';

        final check = await conn.execute(
          "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'users'",
          {'db': dbName},
        );

        final cnt = int.tryParse(check.rows.first.colByName('cnt').toString()) ?? 0;
        if (cnt > 0) {
            print('Database already initialized; checking for incremental migrations');

            // Ensure any new tables added since initial provisioning are applied.
            // Specifically check for `message_idempotency` which was added to schema
            // as part of idempotent message creation support.
            try {
              final checkIdempo = await conn.execute(
                "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'message_idempotency'",
                {'db': dbName},
              );
              final cntId = int.tryParse(checkIdempo.rows.first.colByName('cnt').toString()) ?? 0;
              if (cntId == 0) {
                print('Applying incremental migration: create message_idempotency');
                await conn.execute('''
                  CREATE TABLE IF NOT EXISTS message_idempotency (
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
                  );
                ''');
                print('Incremental migration applied');
              }
            } catch (e) {
              print('Failed to apply incremental migrations: $e');
            }

            // Ensure refresh_tokens table exists as well (added in later schema updates)
            try {
              final checkRefresh = await conn.execute(
                "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'refresh_tokens'",
                {'db': dbName},
              );
              final cntRef = int.tryParse(checkRefresh.rows.first.colByName('cnt').toString()) ?? 0;
              if (cntRef == 0) {
                print('Applying incremental migration: create refresh_tokens');
                await conn.execute('''
                  CREATE TABLE IF NOT EXISTS refresh_tokens (
                      id INT AUTO_INCREMENT PRIMARY KEY,
                      user_id INT NOT NULL,
                      token VARCHAR(1024) NOT NULL,
                      revoked BOOLEAN DEFAULT FALSE,
                      expires_at TIMESTAMP NULL,
                      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                      INDEX idx_user_id (user_id),
                      INDEX idx_token (token(255))
                  );
                ''');
                print('Incremental migration for refresh_tokens applied');
              }
            } catch (e) {
              print('Failed to create refresh_tokens incremental migration: $e');
            }

            return;
        }
      } catch (e) {
        // If the check fails, continue to attempt migration — keep startup resilient.
        print('Could not verify existing schema: $e — attempting migration');
      }

      // Read the schema file
      final schemaFile = File('lib/database/schema.sql');
      final schemaSQL = await schemaFile.readAsString();

      // Execute the schema as provided. This is run only when schema is missing.
      await conn.execute(schemaSQL);

      print('Database migrations completed successfully');
    } catch (e) {
      print('Error running database migrations: $e');
      rethrow;
    }
  }
  
  static Future<void> initializeDatabase() async {
    // Load environment variables
    final _env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
    await DBConnection.initialize();
    await runMigrations();
  }
}