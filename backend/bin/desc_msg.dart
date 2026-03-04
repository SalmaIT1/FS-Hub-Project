import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

void main() async {
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();

  final res = await conn.execute("DESCRIBE messages");
  for (final row in res.rows) {
    print(row.assoc());
  }

  print('\n--- One Message ---');
  final row = await conn.execute('SELECT * FROM messages LIMIT 1');
  if (row.rows.isNotEmpty) {
    print(row.rows.first.assoc());
  }

  await DBConnection.close();
}
