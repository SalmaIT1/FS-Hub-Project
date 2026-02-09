import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';

typedef WSMessageHandler = void Function(Map<String, dynamic> event);

class WebSocketClient {
  final String url;
  final Future<String> Function() tokenProvider;
  IOWebSocketChannel? _channel;

  WebSocketClient({required this.url, required this.tokenProvider});

  final _connected = StreamController<bool>.broadcast();
  Stream<bool> get connected => _connected.stream;

  final _inbound = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get inbound => _inbound.stream;

  Timer? _reconnectTimer;
  bool _manuallyClosed = false;

  Future<void> connect() async {
    _manuallyClosed = false;
    await _connectOnce();
  }

  Future<void> _connectOnce() async {
    try {
      final token = await tokenProvider();
      // Token is appended to the path so server can extract and verify it.
      // Server route: /ws/chat/<token> authenticates and maps connection to authenticated user.
      final uri = Uri.parse('$url/$token');
      _channel = IOWebSocketChannel.connect(uri.toString());
      _connected.add(true);
      _channel!.stream.listen((data) {
        try {
          final Map<String, dynamic> j = jsonDecode(data as String);
          _inbound.add(j);
        } catch (_) {}
      }, onDone: _onDisconnected, onError: (e) => _onDisconnected());
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onDisconnected() {
    _connected.add(false);
    if (!_manuallyClosed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 2), () async {
      await _connectOnce();
    });
  }

  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _connected.add(false);
  }

  Future<void> send(Map<String, dynamic> event) async {
    final payload = jsonEncode(event);
    try {
      _channel?.sink.add(payload);
    } catch (e) {
      // best-effort; callers should use REST fallback via MessageQueue
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _inbound.close();
    _connected.close();
  }
}
