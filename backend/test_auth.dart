import 'lib/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final db = DBConnection.getConnection();
  
  final users = await db.execute('SELECT id, username FROM users');
  print('--- Users ---');
  for (var r in users.rows) print(r.assoc());
}
