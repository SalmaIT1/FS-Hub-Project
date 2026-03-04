import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

void main() async {
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();

  final res = await conn.execute('SELECT DISTINCT conversation_id FROM messages');
  print('Conversation IDs with messages:');
  for (final row in res.rows) {
    print(row.colByName('conversation_id'));
  }

  await DBConnection.close();
}
