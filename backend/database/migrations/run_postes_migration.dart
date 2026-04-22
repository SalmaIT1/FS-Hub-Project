import 'dart:io';

Future<void> main() async {
  try {
    print('Running migration: Create postes table');
    
    // Read SQL file
    final file = File('create_postes_table.sql');
    if (!await file.exists()) {
      print('❌ SQL file not found: create_postes_table.sql');
      return;
    }
    
    final sqlContent = await file.readAsString();
    print('SQL content loaded. Please run this SQL manually in your MySQL client:');
    print('\n${'='*50}');
    print(sqlContent);
    print('='*50);
    print('\nOr use MySQL command line:');
    print('mysql -u root -p fs_hub < create_postes_table.sql');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
