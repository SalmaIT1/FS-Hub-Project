import 'package:fs_hub_backend/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();
  await conn.execute("UPDATE users SET role = 'Employé' WHERE id = '2'");
  print('User ID 2 reverted to Employé');
}
