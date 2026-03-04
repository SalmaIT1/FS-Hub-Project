import 'dart:async';
import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart';

/// DBConnection wraps a simple connection pool so that DB calls
/// do not pay the cost of a new TCP handshake on every query.
///
/// Pool size defaults to 20. A connection that errors is discarded and
/// replaced. Callers waiting for a free slot time out after 10 seconds to
/// prevent infinite event-loop starvation under heavy load.

class _PooledConnection {
  MySQLConnection? _conn;
  bool _inUse = false;

  final String host;
  final int port;
  final String user;
  final String password;
  final String dbName;
  final bool secure;

  _PooledConnection(
      this.host, this.port, this.user, this.password, this.dbName,
      {this.secure = false});

  bool get inUse => _inUse;

  Future<void> _ensureConnected() async {
    if (_conn != null) return; // assume alive; error recovery handles stale ones
    _conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: dbName,
      secure: secure,
    );
    await _conn!.connect();
  }

  Future<dynamic> execute(String sql, [Map<String, dynamic>? params]) async {
    await _ensureConnected();
    return _conn!.execute(sql, params ?? {});
  }

  Future<T> transaction<T>(Future<T> Function(MySQLConnection c) fn) async {
    await _ensureConnected();
    await _conn!.execute('START TRANSACTION');
    try {
      final res = await fn(_conn!);
      await _conn!.execute('COMMIT');
      return res;
    } catch (e) {
      try {
        // Attempt rollback, but on failure we MUST discard the connection
        await _conn!.execute('ROLLBACK');
      } catch (innerE) {
        print('DB Transaction Rollback Failed: $innerE');
        final c = _conn;
        _conn = null;
        try { await c?.close(); } catch (_) {}
      }
      rethrow;
    }
  }

  void release() => _inUse = false;
  void acquire() => _inUse = true;
}

class _DBProxy {
  final List<_PooledConnection> _pool;

  _DBProxy(this._pool);

  /// Pool acquire with queue-based waiting and a 10-second timeout.
  Future<_PooledConnection> _acquire() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (true) {
      for (final c in _pool) {
        if (!c.inUse) {
          c.acquire();
          return c;
        }
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
            'DB pool exhausted: no connection available after 10s. '
            'Consider increasing pool size.');
      }
      // Yield for one event-loop tick then retry.
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<dynamic> execute(String sql, [Map<String, dynamic>? params]) async {
    final slot = await _acquire();
    try {
      return await slot.execute(sql, params);
    } catch (e) {
      try {
        await slot._conn?.close();
      } catch (_) {}
      slot._conn = null;
      rethrow;
    } finally {
      slot.release();
    }
  }

  Future<T> transaction<T>(Future<T> Function(MySQLConnection c) fn) async {
    final slot = await _acquire();
    try {
      return await slot.transaction(fn);
    } catch (e) {
      try {
        await slot._conn?.close();
      } catch (_) {}
      slot._conn = null;
      rethrow;
    } finally {
      slot.release();
    }
  }
}

class Connection {
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
    final secure = _env['DB_SECURE']?.toLowerCase() != 'false';
    const poolSize = 20; // Sufficient for moderate concurrency.

    final pool = List.generate(
      poolSize,
      (_) => _PooledConnection(host, port, user, password, dbName,
          secure: secure),
    );

    _proxy = _DBProxy(pool);
    _initialized = true;
    print('Database configuration loaded (pool size: $poolSize)');
  }

  /// Returns the shared proxy. Existing callers using
  /// `getConnection().execute(...)` continue to work unchanged.
  static _DBProxy getConnection() {
    if (!_initialized) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return _proxy;
  }

  /// No-op: connections are managed by the pool.
  static Future<void> close() async {
    _initialized = false;
  }
}

class DBConnection {
  static Future<void> initialize() => Connection.initialize();

  static _DBProxy getConnection() => Connection.getConnection();

  static Future<void> close() => Connection.close();
}