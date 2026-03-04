import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  try {
    final env = DotEnv()..load(['.env']);
    final conn = await MySQLConnection.createConnection( host: '127.0.0.1', port: 3306, userName: 'root', password: 'admin', databaseName: 'fs_hub_db' );
    await conn.connect();
    
    print('--- Table: demands ---');
    try {
      final res = await conn.execute('DESCRIBE demands');
      for (final row in res.rows) {
        print('${row.colByName('Field')}: ${row.colByName('Type')}');
      }
    } catch (e) {
      print('DESCRIBE demands FAILED: $e');
    }

    print('\n--- Table: users ---');
    try {
      final res = await conn.execute('DESCRIBE users');
      for (final row in res.rows) {
        print('${row.colByName('Field')}: ${row.colByName('Type')}');
      }
    } catch (e) {
      print('DESCRIBE users FAILED: $e');
    }

    print('\n--- Executing DemandRepository.getAllDemands logic (Admin mode) ---');
    try {
      String query = '''
        SELECT d.id, d.type, d.description, d.status, d.requester_id,
               d.handled_by, d.resolution_notes, d.created_at, d.updated_at,
               u.username as requester_name
        FROM demands d
        LEFT JOIN users u ON d.requester_id = u.id
        WHERE 1=1
      ''';
      query += ' ORDER BY d.created_at DESC';
      final params = <String, dynamic>{};
      
      final result = await conn.execute(query, params);
      print('Result execute SUCCESS. Rows: ${result.rows.length}');
      
      if (result.rows.isNotEmpty) {
        final firstRow = result.rows.first;
        print('First row assoc(): ${firstRow.assoc()}');
      }
    } catch (e, stack) {
      print('DEMAND QUERY ERROR: $e\n$stack');
    }

    await conn.close();
  } catch (e) {
    print('SCRIPT ERROR: $e');
  }
}
