import 'package:fs_hub_backend/database/db_connection.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
  await DBConnection.initialize();
  final conn = await DBConnection.getConnection();
  
  final dbName = env['DB_NAME'] ?? 'fs_hub_db';
  print('Checking database: $dbName');
  
  final tables = [
    'conversations', 
    'conversation_members', 
    'messages',
    'message_reads',
    'message_reactions',
    'typing_events',
    'refresh_tokens'
  ];
  
  for (final table in tables) {
    print('\nTable: $table');
    final result = await conn.execute(
      "SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE FROM information_schema.columns WHERE table_schema = :db AND table_name = :table",
      {'db': dbName, 'table': table},
    );
    
    for (final row in result.rows) {
      print('  ${row.colAt(0)}: ${row.colAt(1)} (${row.colAt(2)})');
    }
  }
}
