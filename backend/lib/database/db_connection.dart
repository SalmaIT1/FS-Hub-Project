import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart';

class DBConnection {
  static MySQLConnection? _connection;
  static bool _initialized = false;
  static late DotEnv _env;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    _env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
    
    final host = _env['DB_HOST'] ?? 'localhost';
    final port = int.tryParse(_env['DB_PORT'] ?? '3306') ?? 3306;
    final user = _env['DB_USER'] ?? 'root';
    final password = _env['DB_PASSWORD'] ?? '';
    final dbName = _env['DB_NAME'] ?? 'fs_hub_db';

    _connection = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: dbName,
      secure: true, // Enable SSL for caching_sha2_password support
    );

    await _connection!.connect();
    _initialized = true;
    
    print('Database connected successfully');
  }

  static MySQLConnection getConnection() {
    if (_connection == null || !_initialized) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return _connection!;
  }

  static Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _initialized = false;
    }
  }
}