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
                      user_id VARCHAR(50) NOT NULL,
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

            // Migration: Convert all user_id columns to VARCHAR(50) if they are INT
            // We check each table individually to ensure complete coverage even if some were partially migrated.
            final tablesToFix = {
              'conversations': 'created_by',
              'conversation_members': 'user_id',
              'messages': 'sender_id',
              'message_reads': 'user_id',
              'message_reactions': 'user_id',
              'typing_events': 'user_id',
              'refresh_tokens': 'user_id',
              'users': 'id',
            };

            for (final entry in tablesToFix.entries) {
              try {
                final table = entry.key;
                final column = entry.value;
                
                final checkCol = await conn.execute(
                  "SELECT DATA_TYPE FROM information_schema.columns WHERE table_schema = :db AND table_name = :table AND column_name = :col",
                  {'db': dbName, 'table': table, 'col': column},
                );
                
                if (checkCol.rows.isNotEmpty && checkCol.rows.first.colAt(0).toString().toLowerCase().contains('int')) {
                   print('Applying migration: Convert $table.$column to VARCHAR(50)');
                   try {
                     await conn.execute('SET FOREIGN_KEY_CHECKS = 0');
                     try {
                       await conn.execute('ALTER TABLE $table MODIFY $column VARCHAR(50) NOT NULL');
                       print('  Successfully converted $table.$column');
                     } finally {
                       await conn.execute('SET FOREIGN_KEY_CHECKS = 1');
                     }
                   } catch (e) {
                     print('Failed to convert table ${entry.key}: $e');
                   }
                }
              } catch (e) {
                print('Failed to convert table ${entry.key}: $e');
              }
            }

          // Ensure presence columns exist in users table
          try {
            final checkPresence = await conn.execute(
              "SELECT COLUMN_NAME FROM information_schema.columns WHERE table_schema = :db AND table_name = 'users' AND column_name = 'is_online'",
              {'db': dbName},
            );
            if (checkPresence.rows.isEmpty) {
              print('Applying migration: Add presence columns to users table');
              await conn.execute('ALTER TABLE users ADD COLUMN is_online BOOLEAN DEFAULT FALSE, ADD COLUMN last_seen DATETIME NULL');
              print('Presence columns added successfully');
            }
          } catch (e) {
            print('Failed to check/add presence columns: $e');
          }

          // Ensure departements table exists
          try {
            final checkDept = await conn.execute(
              "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'departements'",
              {'db': dbName},
            );
            final cntDept = int.tryParse(checkDept.rows.first.colByName('cnt').toString()) ?? 0;
            if (cntDept == 0) {
              print('Applying migration: Create departements table');
              await conn.execute('''
                CREATE TABLE IF NOT EXISTS departements (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    nom VARCHAR(100) NOT NULL,
                    budget_annuel DECIMAL(12,2) DEFAULT 0.00,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                );
              ''');
              print('Departements table created successfully');
            } else {
              // Ensure incremental columns like budget_annuel, created_at, updated_at exist
              final columnsCheck = await conn.execute(
                "SELECT column_name FROM information_schema.columns WHERE table_schema = :db AND table_name = 'departements'",
                {'db': dbName},
              );
              final existingCols = columnsCheck.rows.map((r) => r.colAt(0).toString().toLowerCase()).toSet();
              
              if (!existingCols.contains('budget_annuel')) {
                print('Migrating: Adding budget_annuel to departements');
                await conn.execute("ALTER TABLE departements ADD COLUMN budget_annuel DECIMAL(12,2) DEFAULT 0.00");
              }
              if (!existingCols.contains('created_at')) {
                print('Migrating: Adding created_at to departements');
                await conn.execute("ALTER TABLE departements ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP");
              }
              if (!existingCols.contains('updated_at')) {
                print('Migrating: Adding updated_at to departements');
                await conn.execute("ALTER TABLE departements ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");
              }
            }
          } catch (e) {
            print('Failed to check/create departements table: $e');
          }

          // Ensure projets table exists
          try {
            final checkProjets = await conn.execute(
              "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'projets'",
              {'db': dbName},
            );
            final cntProjets = int.tryParse(checkProjets.rows.first.colByName('cnt').toString()) ?? 0;
            if (cntProjets == 0) {
              print('Applying migration: Create projets table');
              await conn.execute('''
                CREATE TABLE IF NOT EXISTS projets (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    nom VARCHAR(200) NOT NULL,
                    description TEXT,
                    client_id INT,
                    budget DECIMAL(15,2) DEFAULT 0.00,
                    cout_estime DECIMAL(15,2) DEFAULT 0.00,
                    date_debut DATE,
                    date_fin_prevue DATE,
                    priorite ENUM('Faible','Moyenne','Haute','Critique') DEFAULT 'Moyenne',
                    statut ENUM('Planifié','En cours','Terminé','En retard') DEFAULT 'Planifié',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL
                );
              ''');
              print('Projets table created successfully');
            }
          } catch (e) {
            print('Failed to check/create projets table: $e');
          }

          // Ensure sprints table exists
          try {
            final checkSprints = await conn.execute(
              "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'sprints'",
              {'db': dbName},
            );
            final cntSprints = int.tryParse(checkSprints.rows.first.colByName('cnt').toString()) ?? 0;
            if (cntSprints == 0) {
              print('Applying migration: Create sprints table');
              await conn.execute('''
                CREATE TABLE IF NOT EXISTS sprints (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    projet_id INT,
                    nom VARCHAR(100) NOT NULL,
                    date_debut DATE,
                    date_fin DATE,
                    objectif TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE CASCADE
                );
              ''');
              print('Sprints table created successfully');
            }
          } catch (e) {
            print('Failed to check/create sprints table: $e');
          }

          // Ensure projet_membres table exists
          try {
            final checkMembers = await conn.execute(
              "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'projet_membres'",
              {'db': dbName},
            );
            final cntMembers = int.tryParse(checkMembers.rows.first.colByName('cnt').toString()) ?? 0;
            if (cntMembers == 0) {
              print('Applying migration: Create projet_membres table');
              await conn.execute('''
                CREATE TABLE IF NOT EXISTS projet_membres (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    projet_id INT NOT NULL,
                    employee_id VARCHAR(50) NOT NULL,
                    role VARCHAR(100) DEFAULT 'Membre',
                    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE CASCADE,
                    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
                    UNIQUE KEY unique_proj_emp (projet_id, employee_id)
                );
              ''');
              print('Projet_membres table created successfully');
            }
          } catch (e) {
            print('Failed to check/create projet_membres table: $e');
          }

          // Ensure taches table exists
          try {
            final checkTaches = await conn.execute(
              "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'taches'",
              {'db': dbName},
            );
            final cntTaches = int.tryParse(checkTaches.rows.first.colByName('cnt').toString()) ?? 0;
            if (cntTaches == 0) {
              print('Applying migration: Create taches table');
              await conn.execute('''
                CREATE TABLE IF NOT EXISTS taches (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    sprint_id INT,
                    employee_id VARCHAR(50),
                    titre VARCHAR(200) NOT NULL,
                    description TEXT,
                    estimation_heures INT DEFAULT 0,
                    heures_reelles INT DEFAULT 0,
                    statut ENUM('Backlog','ToDo','InProgress','Testing','Done') DEFAULT 'ToDo',
                    priorite ENUM('Low','Medium','High') DEFAULT 'Medium',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    FOREIGN KEY (sprint_id) REFERENCES sprints(id) ON DELETE CASCADE,
                    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL
                );
              ''');
              print('Taches table created successfully');
            }
          } catch (e) {
            print('Failed to check/create taches table: $e');
          }

          // Ensure factures table exists
          try {
            final checkFactures = await conn.execute(
              "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'factures'",
              {'db': dbName},
            );
            final cntFactures = int.tryParse(checkFactures.rows.first.colByName('cnt').toString()) ?? 0;
            if (cntFactures == 0) {
              print('Applying migration: Create factures table');
              await conn.execute('''
                CREATE TABLE IF NOT EXISTS factures (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    projet_id INT,
                    client_id INT,
                    numero_facture VARCHAR(50),
                    montant_ht DECIMAL(15,2),
                    tva DECIMAL(5,2),
                    montant_ttc DECIMAL(15,2),
                    date_emission DATE,
                    date_echeance DATE,
                    statut ENUM('Brouillon','Envoyée','Payée','En retard') DEFAULT 'Brouillon',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE SET NULL,
                    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL
                );
              ''');
              print('Factures table created successfully');
            }
          } catch (e) {
            print('Failed to check/create factures table: $e');
          }

          // Ensure paiements table exists
          try {
            final checkPaiements = await conn.execute(
              "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = :db AND table_name = 'paiements'",
              {'db': dbName},
            );
            final cntPaiements = int.tryParse(checkPaiements.rows.first.colByName('cnt').toString()) ?? 0;
            if (cntPaiements == 0) {
              print('Applying migration: Create paiements table');
              await conn.execute('''
                CREATE TABLE IF NOT EXISTS paiements (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    facture_id INT,
                    montant DECIMAL(15,2),
                    mode ENUM('Virement','Espèces','Carte','Chèque'),
                    date_paiement DATE,
                    reference_transaction VARCHAR(100),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    FOREIGN KEY (facture_id) REFERENCES factures(id) ON DELETE CASCADE
                );
              ''');
              print('Paiements table created successfully');
            }
          } catch (e) {
            print('Failed to check/create paiements table: $e');
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