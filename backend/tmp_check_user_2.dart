import 'package:fs_hub_backend/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();
  
  final res = await conn.execute("SELECT id, role, nom, prenom FROM users WHERE id = '2'");
  if (res.rows.isEmpty) {
    print('User 2 NOT FOUND');
    final all = await conn.execute("SELECT id, role, nom FROM users LIMIT 5");
    for (final r in all.rows) {
        print('OTHER: ID=${r.colByName("id")}, Role=${r.colByName("role")}, name=${r.colByName("nom")}');
    }
  } else {
    for (final r in res.rows) {
      print('ID: ${r.colByName("id")}, Role: ${r.colByName("role")}, Name: ${r.colByName("nom")} ${r.colByName("prenom")}');
    }
  }
}
