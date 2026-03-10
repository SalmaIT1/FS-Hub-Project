import 'lib/shared/database/connection.dart';
import 'package:mysql_client/mysql_client.dart';

void main() async {
  await DBConnection.initialize();
  final db = DBConnection.getConnection();
  
  final results = await db.execute('SELECT * FROM roles LIMIT 1');
  if (results.rows.isEmpty) {
    print('No roles found.');
    return;
  }
  
  final row = results.rows.first;
  final assoc = row.assoc();
  print('Assoc keys: ' + assoc.keys.toList().toString());
  for (var entry in assoc.entries) {
    print('Field: ' + entry.key + ', Value: ' + entry.value.toString() + ', Type: ' + entry.value.runtimeType.toString());
  }
}
