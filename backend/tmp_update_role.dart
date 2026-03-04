import 'package:fs_hub_backend/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();
  await conn.execute("UPDATE users SET role = 'Admin' WHERE id = '2'");
  print('User ID 2 updated to Admin');
}
