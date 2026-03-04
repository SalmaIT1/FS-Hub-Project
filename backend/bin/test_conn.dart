import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart';
import 'dart:io';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load(['backend/.env']);
  
  final host = env['DB_HOST'] ?? '127.0.0.1';
  final port = int.tryParse(env['DB_PORT'] ?? '3306') ?? 3306;
  final user = env['DB_USER'] ?? 'root';
  final password = env['DB_PASSWORD'] ?? 'admin';
  final dbName = env['DB_NAME'] ?? 'fs_hub_db';

  print('Testing connection to $host:$port as $user...');
  
  try {
    print('Trying with secure: true...');
    final conn1 = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: dbName,
      secure: true,
    );
    await conn1.connect();
    print('✅ Connection successful with secure: true');
    await conn1.close();
  } catch (e) {
    print('❌ Connection failed with secure: true: $e');
  }

  try {
    print('\nTrying with secure: false...');
    final conn2 = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: dbName,
      secure: false,
    );
    await conn2.connect();
    print('✅ Connection successful with secure: false');
    await conn2.close();
  } catch (e) {
    print('❌ Connection failed with secure: false: $e');
  }
}
