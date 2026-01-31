import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart';
import 'dart:io';

class DB {
  static MySQLConnection? _connection;

  static Future<MySQLConnection> getConnection() async {
    if (_connection != null && _connection!.connected) {
      return _connection!;
    }

    var env = DotEnv(includePlatformEnvironment: true)..load(['../.env']);
    
    _connection = await MySQLConnection.createConnection(
      host: env['DB_HOST'] ?? '127.0.0.1',
      port: int.parse(env['DB_PORT'] ?? '3306'),
      userName: env['DB_USER'] ?? 'root',
      password: env['DB_PASSWORD'] ?? 'admin',
      databaseName: env['DB_NAME'] ?? 'fs_hub_db',
    );

    try {
      await _connection!.connect();
    } catch (e) {
      print('DATABASE CONNECTION ERROR: $e');
      print('Check if MySQL is running and credentials in .env are correct.');
      rethrow;
    }
    return _connection!;
  }
}
