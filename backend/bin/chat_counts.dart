import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

void main() async {
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();

  final resMsg = await conn.execute('SELECT COUNT(*) as cnt FROM messages');
  print('Total Messages: ${resMsg.rows.first.colByName('cnt')}');

  final resConv = await conn.execute('SELECT COUNT(*) as cnt FROM conversations');
  print('Total Conversations: ${resConv.rows.first.colByName('cnt')}');

  final resUsers = await conn.execute('SELECT COUNT(*) as cnt FROM users');
  print('Total Users: ${resUsers.rows.first.colByName('cnt')}');

  await DBConnection.close();
}
