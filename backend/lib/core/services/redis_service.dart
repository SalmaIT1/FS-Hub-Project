import 'dart:async';
import 'dart:convert';
import 'package:redis/redis.dart';
import 'package:dotenv/dotenv.dart';

class RedisService {
  static final RedisService _instance = RedisService._internal();
  factory RedisService() => _instance;
  RedisService._internal();

  Command? _command;
  PubSub? _pubsub;
  bool _isConnected = false;
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> initialize() async {
    if (_isConnected) return;

    // includePlatformEnvironment: true ensures Docker/Render env vars are read,
    // not just the .env file (which doesn't exist in containers).
    final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
    final host = env['REDIS_HOST'] ?? 'localhost';
    final port = int.tryParse(env['REDIS_PORT'] ?? '6379') ?? 6379;
    final password = env['REDIS_PASSWORD'];

    try {
      final conn = RedisConnection();
      _command = await conn.connect(host, port);
      
      if (password != null && password.isNotEmpty) {
        await _command!.send_object(['AUTH', password]);
      }
      
      _isConnected = true;
      print('Connected to Redis at $host:$port');
      
      // Setup subscriber for cross-instance events
      _setupSubscriber(host, port, password);
    } catch (e) {
      print('Redis connection failed: $e. Running in standalone mode.');
      _isConnected = false;
    }
  }

  void _setupSubscriber(String host, int port, String? password) async {
    try {
      final conn = RedisConnection();
      final sub = await conn.connect(host, port);
      if (password != null && password.isNotEmpty) {
        await sub.send_object(['AUTH', password]);
      }
      
      _pubsub = PubSub(sub);
      _pubsub!.subscribe(['fshub:events']);
      
      _pubsub!.getStream().listen((message) {
        // Redis package returns [type, channel, content]
        if (message.length >= 3) {
          final content = message[2];
          try {
            final data = jsonDecode(content.toString());
            _messageController.add(data);
          } catch (_) {}
        }
      });
    } catch (e) {
      print('Redis subscriber failed: $e');
    }
  }

  Future<void> publish(String channel, Map<String, dynamic> message) async {
    if (!_isConnected) return;
    await _command!.send_object(['PUBLISH', channel, jsonEncode(message)]);
  }

  Future<void> setUserOnline(String userId, String connectionId) async {
    if (!_isConnected) return;
    await _command!.send_object(['SADD', 'user:online:$userId', connectionId]);
    await _command!.send_object(['EXPIRE', 'user:online:$userId', 3600]); // 1 hour TTL backup
  }

  Future<void> setUserOffline(String userId, String connectionId) async {
    if (!_isConnected) return;
    await _command!.send_object(['SREM', 'user:online:$userId', connectionId]);
  }

  Future<bool> isUserOnline(String userId) async {
    if (!_isConnected) return false;
    final count = await _command!.send_object(['SCARD', 'user:online:$userId']);
    return (count as int) > 0;
  }
  
  Future<List<String>> getOnlineUsers(List<String> userIds) async {
    if (!_isConnected) return [];
    
    final results = <String>[];
    for (final id in userIds) {
      if (await isUserOnline(id)) {
        results.add(id);
      }
    }
    return results;
  }

  Future<bool> checkAndSetIdempotencyKey(String key, {int ttlSeconds = 86400}) async {
    if (!_isConnected) return true; // Fail-open: Redis down → allow request through
    try {
      // SET key value EX seconds NX
      // NX: Only set the key if it does not already exist.
      // Returns 'OK' if successful, null if key exists.
      final result = await _command!.send_object(['SET', 'idempotency:$key', '1', 'EX', ttlSeconds, 'NX']);
      return result == 'OK';
    } catch (e) {
      print('[REDIS-IDEMPOTENCY] Error: $e');
      return true; // Fail-open: If Redis is down, we allow the request to proceed (sacrificing idempotency).
    }
  }

  Future<void> set(String key, String value, {int? ttlSeconds}) async {
    if (!_isConnected) return;
    if (ttlSeconds != null) {
      await _command!.send_object(['SET', key, value, 'EX', ttlSeconds]);
    } else {
      await _command!.send_object(['SET', key, value]);
    }
  }

  Future<dynamic> get(String key) async {
    if (!_isConnected) return null;
    return await _command!.send_object(['GET', key]);
  }
}
