import 'dart:io';
import 'package:mysql1/mysql1.dart';

Future<void> main() async {
  final conn = await MySqlConnection.connect(
    ConnectionSettings(
      host: 'localhost',
      user: 'root',
      password: '',
      db: 'fs_hub',
    ),
  );

  try {
    print('Running migration: Add is_active column to employees table');
    
    // Add is_active column to employees table
    await conn.query('''
      ALTER TABLE employees ADD COLUMN is_active BOOLEAN DEFAULT TRUE
    ''');
    
    print('✅ is_active column migration completed successfully!');
    
  } catch (e) {
    if (e.toString().contains('Duplicate column name')) {
      print('✅ Column is_active already exists - no migration needed');
    } else {
      print('❌ Migration failed: $e');
    }
  } finally {
    await conn.close();
  }
}
