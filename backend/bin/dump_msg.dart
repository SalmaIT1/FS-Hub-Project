import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

void main() async {
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();

  final res = await conn.execute("SELECT id, conversation_id, sender_id, content, is_deleted FROM messages");
  for (final row in res.rows) {
    print(row.assoc());
  }

  await DBConnection.close();
}
