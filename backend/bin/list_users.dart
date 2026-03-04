import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

void main() async {
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();

  final res = await conn.execute('SELECT id, username FROM users');
  for (final row in res.rows) {
    print(row.assoc());
  }

  await DBConnection.close();
}
