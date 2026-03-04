import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fs_hub/shared/models/chat_models.dart';

class ChatSocketDatasource {
  final String wsUrl;
  final Future<String> Function() tokenProvider;
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _onlineController = StreamController<bool>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationEventController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get onlineStream => _onlineController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get conversationEventStream => _conversationEventController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  ChatSocketDatasource({required this.wsUrl, required this.tokenProvider});

  Future<void> connect() async {
    if (_isConnected) return;
    _reconnectTimer?.cancel();
    
    try {
      final token = await tokenProvider();
      final uri = Uri.parse('$wsUrl?token=$token');
      
      print('[WS] Connecting to $wsUrl...');
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _handleMessage(json);
          } catch (e) {
            print('[WS] Parse error: $e');
          }
        },
        onError: (error) {
          print('[WS] Error: $error');
          _onDisconnected();
        },
        onDone: () {
          print('[WS] Connection closed');
          _onDisconnected();
        },
        cancelOnError: true,
      );
      
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);
      _startHeartbeat();
    } catch (e) {
      print('[WS] Connection failed: $e');
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _connectionController.add(false);
    _onlineController.add(false);
    _heartbeatTimer?.cancel();
    _channel = null;
    
    // Auto-reconnect
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectAttempts < 5 ? 2 : 10), () {
      _reconnectAttempts++;
      connect();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch}));
      }
    });
  }

  void _handleMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    
    switch (type) {
      case 'connected':
        _onlineController.add(true);
        break;
      case 'message':
      case 'new_message':
        final msgData = json['message'] ?? json['data'];
        if (msgData != null) {
          final msg = Map<String, dynamic>.from(msgData as Map);
          msg['isFromMe'] = msg['isFromMe'] ?? false;
          _messageController.add(ChatMessage.fromJson(msg));
        }
        break;
      case 'online':
        _onlineController.add(true);
        break;
      case 'offline':
        _onlineController.add(false);
        break;
      case 'presence':
        final payload = json['payload'] ?? json['data'];
        if (payload != null) {
          _presenceController.add(Map<String, dynamic>.from(payload as Map));
        }
        break;
      case 'typing':
        final payload = json['payload'] ?? json['data'];
        if (payload != null) {
          _typingController.add(Map<String, dynamic>.from(payload as Map));
        }
        break;
      case 'conversation:deleted':
        final payload = json['payload'];
        if (payload != null) {
          _conversationEventController.add({
            'type': 'deleted',
            ...Map<String, dynamic>.from(payload as Map),
          });
        }
        break;
    }
  }

  void joinConversation(String conversationId) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'join',
      'conversationId': conversationId,
    }));
  }

  void leaveConversation(String conversationId) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'leave',
      'conversationId': conversationId,
    }));
  }

  void sendMessage({
    required String conversationId,
    required String content,
    required String senderId,
    String? clientMessageId,
  }) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'conversationId': conversationId,
      'content': content,
      'senderId': senderId,
      'clientMessageId': clientMessageId,
    }));
  }

  void sendTypingIndicator(String conversationId) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'typing',
      'conversationId': conversationId,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
    _onlineController.close();
  }
}
