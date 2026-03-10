import 'package:fs_hub_backend/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final db = DBConnection.getConnection();
  final result = await db.execute('SELECT id, nom FROM roles');
  for (var row in result.rows) {
    print('${row.colAt(0)}: ${row.colAt(1)}');
  }
}
