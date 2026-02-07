import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'db_connection.dart';

class DBMigration {
  static Future<void> runMigrations() async {
    try {
      final conn = DBConnection.getConnection();
      
      // Read the schema file
      final schemaFile = File('lib/database/schema.sql');
      final schemaSQL = await schemaFile.readAsString();
      
      // Execute the schema
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