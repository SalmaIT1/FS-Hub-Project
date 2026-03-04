import 'package:fs_hub_backend/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();
  
  final res = await conn.execute('SELECT id, role FROM users');
  for (final r in res.rows) {
    print('ID: ${r.colByName("id")}, Role: ${r.colByName("role")}');
  }
}
