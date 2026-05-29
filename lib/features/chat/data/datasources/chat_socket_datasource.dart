import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fs_hub/features/chat/data/datasources/chat_ws_event_parser.dart';
import 'package:fs_hub/shared/models/chat_models.dart';

class ChatSocketDatasource {
  final String wsUrl;
  final String apiBaseUrl;
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
  String? _connectionId;
  String? get connectionId => _connectionId;
  int _reconnectAttempts = 0;

  ChatSocketDatasource({
    required this.wsUrl, 
    required this.apiBaseUrl,
    required this.tokenProvider,
  });

  Future<void> connect() async {
    if (_isConnected) return;
    _reconnectTimer?.cancel();
    
    try {
      final token = await tokenProvider();
      
      // H-1/H-2 FIX: Negotiate a short-lived ticket before opening the socket.
      // This prevents long-lived JWTs from appearing in URL logs.
      final ticketRes = await http.post(
        Uri.parse('$apiBaseUrl/v1/auth/ws-ticket'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (ticketRes.statusCode != 200) {
        print('[WS] Ticket negotiation failed: ${ticketRes.body}');
        _onDisconnected();
        return;
      }

      final ticket = jsonDecode(ticketRes.body)['ticket'];
      final uri = Uri.parse('$wsUrl?ticket=$ticket&ngrok-skip-browser-warning=1');
      
      print('[WS] Connecting to $wsUrl with ticket...');
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

    // P1-1 FIX: Exponential backoff with ±20% random jitter.
    // Prevents thundering herd when many clients reconnect simultaneously after
    // a server restart. Caps at 64 seconds to bound worst-case retry latency.
    _reconnectTimer?.cancel();
    final backoffMs = (1000 * (1 << _reconnectAttempts.clamp(0, 6))).clamp(1000, 64000);
    final jitterMs = (backoffMs * 0.2 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000).toInt();
    final delayMs = backoffMs + jitterMs;
    print('[WS] Reconnecting in ${delayMs}ms (attempt #${_reconnectAttempts + 1}, backoff=${backoffMs}ms, jitter=${jitterMs}ms)');
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
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
    for (final event in ChatWsEventParser.parse(json)) {
      switch (event) {
        case ChatWsConnectionAck(:final connectionId):
          _connectionId = connectionId;
          print('[WS] Received connection_ack. ID: $_connectionId');
          _onlineController.add(true);
        case ChatWsOnlineChanged(:final isOnline):
          _onlineController.add(isOnline);
        case ChatWsIncomingMessage(:final message):
          _messageController.add(message);
        case ChatWsMessageAck(:final clientMessageId):
          _messageController.add(ChatMessage(
            id: clientMessageId,
            clientMessageId: clientMessageId,
            conversationId: '',
            senderId: '',
            senderName: '',
            type: 'text',
            createdAt: DateTime.now(),
            isFromMe: true,
            state: MessageState.sent,
            content: '',
          ));
          print('[WS] Message ACK received: $clientMessageId');
        case ChatWsMessageFailed(:final clientMessageId, :final errorMessage):
          _messageController.add(ChatMessage(
            id: clientMessageId,
            clientMessageId: clientMessageId,
            conversationId: '',
            senderId: '',
            senderName: '',
            type: 'text',
            createdAt: DateTime.now(),
            isFromMe: true,
            state: MessageState.failed,
            content: errorMessage,
          ));
        case ChatWsPresence(:final payload):
          _presenceController.add(payload);
        case ChatWsTyping(:final payload):
          _typingController.add(payload);
        case ChatWsConversationDeleted(:final conversationId):
          _conversationEventController.add({
            'type': 'deleted',
            'conversationId': conversationId,
          });
        case ChatWsServerError(:final message):
          print('[WS] Error from server: $message');
        case ChatWsUnknown(:final type):
          if (type != null) print('[WS] Unhandled event type: $type');
      }
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
    if (!_isConnected || _channel == null) {
      if (clientMessageId != null) {
        _messageController.add(ChatMessage(
          id: clientMessageId,
          clientMessageId: clientMessageId,
          conversationId: conversationId,
          senderId: senderId,
          senderName: '',
          type: 'text',
          createdAt: DateTime.now(),
          isFromMe: true,
          state: MessageState.failed,
          content: content,
        ));
      }
      return;
    }
    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'conversationId': conversationId,
      'content': content,
      'senderId': senderId,
      'clientMessageId': clientMessageId,
    }));
  }

  void sendTypingIndicator(String conversationId, bool isTyping) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'typing',
      'conversationId': conversationId,
      'isTyping': isTyping,
      'state': isTyping ? 'typing' : 'stopped',
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
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    // P2 FIX: Close all stream controllers to prevent memory leaks
    // on logout/re-login flows. Previously only 3 of 6 were closed.
    _messageController.close();
    _connectionController.close();
    _onlineController.close();
    _presenceController.close();
    _typingController.close();
    _conversationEventController.close();
  }
}
