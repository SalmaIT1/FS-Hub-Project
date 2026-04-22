import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WSMessageHandler = void Function(Map<String, dynamic> event);

class WebSocketClient {
  final String url;
  final String apiUrl; // P0-03 FIX: Added apiUrl for ticket negotiation
  final Future<String> Function() tokenProvider;
  WebSocketChannel? _channel;

  WebSocketClient({
    required this.url, 
    required this.apiUrl, 
    required this.tokenProvider
  });

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
      
      // P0-03 FIX: Standardized secure ticket negotiation (Surgical Patch)
      // We no longer pass the long-lived JWT in the URL path.
      final response = await _fetchTicket(token);
      final ticket = response['ticket'];
      final uri = Uri.parse('$url?ticket=$ticket');
      
      _channel = WebSocketChannel.connect(uri);
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

  /// P0-03 FIX: Helper to negotiate short-lived WS ticket
  Future<Map<String, dynamic>> _fetchTicket(String token) async {
    final uri = Uri.parse('$apiUrl/v1/auth/ws-ticket');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to negotiate WebSocket ticket: ${response.statusCode}');
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
