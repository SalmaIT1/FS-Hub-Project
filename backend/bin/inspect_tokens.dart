import 'dart:convert';
import '../lib/database/db_connection.dart';

Future<void> main() async {
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();
  final res = await conn.execute('SELECT id, user_id, token, revoked, expires_at, created_at FROM refresh_tokens ORDER BY id DESC LIMIT 20');
  for (final row in res.rows) {
    print('id=${row.colByName('id')} user=${row.colByName('user_id')} revoked=${row.colByName('revoked')} created=${row.colByName('created_at')} token=${row.colByName('token')}');
  }
}
