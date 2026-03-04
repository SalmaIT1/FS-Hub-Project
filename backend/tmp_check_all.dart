import 'package:fs_hub_backend/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();
  
  print('--- USERS ---');
  final res = await conn.execute("SELECT id, username, role FROM users");
  for (final r in res.rows) {
    print('ID: ${r.colByName("id")}, Username: ${r.colByName("username")}, Role: ${r.colByName("role")}');
  }
  
  print('\n--- EMPLOYEES ---');
  final res2 = await conn.execute("SELECT id, user_id, nom, prenom FROM employees");
  for (final r in res2.rows) {
    print('ID: ${r.colByName("id")}, UserID: ${r.colByName("user_id")}, Name: ${r.colByName("nom")} ${r.colByName("prenom")}');
  }
}
