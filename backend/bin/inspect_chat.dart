import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

void main() async {
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();

  print('--- Conversations ---');
  try {
    final convs = await conn.execute('SELECT id, name, type FROM conversations');
    for (final row in convs.rows) {
      print(row.assoc());
    }
  } catch(e) { print('Error fetching convs: $e'); }

  print('\n--- Messages ---');
  try {
    final msgs = await conn.execute('SELECT id, conversation_id, sender_id, content FROM messages');
    for (final row in msgs.rows) {
      print(row.assoc());
    }
  } catch(e) { print('Error fetching msgs: $e'); }

  print('\n--- Users ---');
  try {
    final users = await conn.execute('SELECT id, username FROM users');
    for (final row in users.rows) {
      print(row.assoc());
    }
  } catch(e) { print('Error fetching users: $e'); }

  await DBConnection.close();
}
