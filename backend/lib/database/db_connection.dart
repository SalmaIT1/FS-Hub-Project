import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart';

/// DBConnection provides a safe proxy for executing queries.
/// Instead of exposing a single shared long-lived connection (which blocks
/// concurrency and is unsafe under load), this implementation holds DB
/// configuration from environment and creates a short-lived connection
/// for each `execute` call. This is a minimal, backward-compatible change
/// so existing code calling `DBConnection.getConnection().execute(...)`
/// continues to work while avoiding a single shared connection.

class _DBProxy {
  final String host;
  final int port;
  final String user;
  final String password;
  final String dbName;
  final bool secure;

  _DBProxy(this.host, this.port, this.user, this.password, this.dbName, {this.secure = false});

  /// Execute a single statement. A new connection is created, used, and closed.
  Future<dynamic> execute(String sql, [Map<String, dynamic>? params]) async {
    final conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: dbName,
      secure: secure,
    );

    await conn.connect();
    try {
      final res = await conn.execute(sql, params ?? {});
      return res;
    } finally {
      try {
        await conn.close();
      } catch (_) {}
    }
  }

  /// Run multiple operations in a single connection inside a transaction.
  /// The callback receives the open `MySQLConnection` to perform several
  /// `execute` calls atomically. This is needed for operations like
  /// refresh token rotation and idempotent message inserts.
  Future<T> transaction<T>(Future<T> Function(MySQLConnection conn) callback) async {
    final conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: dbName,
      secure: secure,
    );

    await conn.connect();
    try {
      await conn.execute('START TRANSACTION');
      final res = await callback(conn);
      await conn.execute('COMMIT');
      return res;
    } catch (e) {
      try {
        await conn.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    } finally {
      try {
        await conn.close();
      } catch (_) {}
    }
  }
}

class DBConnection {
  static late DotEnv _env;
  static bool _initialized = false;
  static late _DBProxy _proxy;

  static Future<void> initialize() async {
    if (_initialized) return;

    _env = DotEnv(includePlatformEnvironment: true)..load(['.env']);

    final host = _env['DB_HOST'] ?? 'localhost';
    final port = int.tryParse(_env['DB_PORT'] ?? '3306') ?? 3306;
    final user = _env['DB_USER'] ?? 'root';
    final password = _env['DB_PASSWORD'] ?? '';
    final dbName = _env['DB_NAME'] ?? 'fs_hub_db';

    _proxy = _DBProxy(host, port, user, password, dbName, secure: true);
    _initialized = true;
    print('Database configuration loaded');
  }

  /// Returns a proxy object that exposes `execute(sql, params)`.
  /// Existing callers that call `getConnection().execute(...)` continue to work.
  static _DBProxy getConnection() {
    if (!_initialized) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return _proxy;
  }

  /// No-op close: connections are short-lived and closed by the proxy.
  static Future<void> close() async {
    _initialized = false;
  }
}