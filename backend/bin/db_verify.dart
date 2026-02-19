import 'package:fs_hub_backend/database/db_connection.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
  await DBConnection.initialize();
  final conn = await DBConnection.getConnection();
  final dbName = env['DB_NAME'] ?? 'fs_hub_db';
  
  final query = """
    SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE 
    FROM information_schema.columns 
    WHERE table_schema = :db 
    AND (COLUMN_NAME LIKE '%user_id%' OR COLUMN_NAME = 'sender_id' OR COLUMN_NAME = 'created_by')
    AND DATA_TYPE = 'int'
  """;
  
  final result = await conn.execute(query, {'db': dbName});
  
  if (result.rows.isEmpty) {
    print('SUCCESS: No INT columns found for user IDs.');
  } else {
    print('FAILURE: Found INT columns for user IDs:');
    for (final row in result.rows) {
      print('  ${row.colAt(0)}.${row.colAt(1)} is ${row.colAt(2)}');
    }
  }
}
