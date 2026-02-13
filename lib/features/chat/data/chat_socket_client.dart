import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../domain/chat_entities.dart';
import '../domain/message_state_machine.dart';

/// Typed WebSocket events from backend
abstract class ChatSocketEvent {
  const ChatSocketEvent();
}

/// Connection established
class ConnectedEvent extends ChatSocketEvent {
  final String userId;
  final String connectionId;
  const ConnectedEvent({required this.userId, required this.connectionId});
}

/// Message created (broadcast to all participants)
class MessageCreatedEvent extends ChatSocketEvent {
  final ChatMessage message;
  const MessageCreatedEvent({required this.message});
}

/// Message delivered to recipient
class MessageDeliveredEvent extends ChatSocketEvent {
  final String messageId;
  final String recipientId;
  final DateTime deliveredAt;
  const MessageDeliveredEvent({
    required this.messageId,
    required this.recipientId,
    required this.deliveredAt,
  });
}

/// Message read by recipient
class MessageReadEvent extends ChatSocketEvent {
  final String messageId;
  final String readByUserId;
  final DateTime readAt;
  const MessageReadEvent({
    required this.messageId,
    required this.readByUserId,
    required this.readAt,
  });
}

/// Typing indicator
class TypingEvent extends ChatSocketEvent {
  final String conversationId;
  final String userId;
  final bool isTyping;
  const TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });
}

/// Connection error or server error
class ErrorEvent extends ChatSocketEvent {
  final String message;
  const ErrorEvent({required this.message});
}

/// WebSocket client for real-time chat
/// 
/// Lifecycle:
/// 1. connect(jwt) → waits for ConnectedEvent
/// 2. Receives typed events from backend
/// 3. disconnect() → closes cleanly
/// 
/// Backend contract:
/// - Server sends: {type: 'connected', data: {userId, connectionId}}
/// - Server sends: {type: 'message:created', payload: {message: {...}}}
/// - Server sends: {type: 'delivered', payload: {messageId, recipientId, deliveredAt}}
/// - Server sends: {type: 'read', payload: {messageId, readByUserId, readAt}}
/// - Server sends: {type: 'typing', payload: {conversationId, userId, state}}
/// - Server sends: {type: 'error', message: string}
class ChatSocketClient {
  final String wsUrl;
  final Future<String> Function() tokenProvider;

  WebSocketChannel? _channel;
  final StreamController<ChatSocketEvent> _eventController = 
      StreamController<ChatSocketEvent>.broadcast();
  
  Stream<ChatSocketEvent> get events => _eventController.stream;
  bool get isConnected => _channel != null;

  ChatSocketClient({
    required this.wsUrl,
    required this.tokenProvider,
  });

  /// Connect to backend WebSocket
  /// 
  /// Backend expects JWT in path: ws://host/ws/chat/{token}
  Future<void> connect() async {
    try {
      if (isConnected) await disconnect();

      final token = await tokenProvider();
      print('[WS-CONNECT] Token received: ${token.isNotEmpty ? "present (${token.length} chars)" : "EMPTY"}');
      
      if (token.isEmpty) {
        print('[WS-CONNECT] ERROR: Token is empty! Cannot connect to WebSocket');
        throw Exception('JWT token is empty - cannot authenticate WebSocket');
      }

      final url = Uri.parse('$wsUrl/chat/$token');
      print('[WS-CONNECT] Connecting to: $wsUrl/chat/[token]');

      _channel = WebSocketChannel.connect(url);
      print('[WS-CONNECT] WebSocket channel connected');

      // Listen for incoming events
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          print('[WS-CONNECT] WebSocket error: $error');
          _eventController.add(ErrorEvent(message: 'WebSocket error: $error'));
          _channel = null;
        },
        onDone: () {
          print('[WS-CONNECT] WebSocket connection closed');
          _channel = null;
        },
      );
    } catch (e) {
      print('[WS-CONNECT] Connection failed: $e');
      _eventController.add(ErrorEvent(message: 'Failed to connect: $e'));
      rethrow;
    }
  }

  /// Send ping to keep connection alive
  void ping() {
    if (isConnected) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      } catch (e) {
        _eventController.add(ErrorEvent(message: 'Ping failed: $e'));
      }
    }
  }

  /// Send a message via WebSocket (alternative to REST)
  /// 
  /// Backend expects:
  /// {
  ///   type: 'message',
  ///   data: {
  ///     conversationId: string,
  ///     content: string,
  ///     type: 'text'|'file'|...,
  ///     clientMessageId?: string,
  ///   }
  /// }
  void sendMessage({
    required String conversationId,
    required String content,
    String? clientMessageId,
  }) {
    if (!isConnected) {
      _eventController.add(ErrorEvent(message: 'Not connected'));
      return;
    }

    try {
      _channel!.sink.add(jsonEncode({
        'type': 'message',
        'data': {
          'conversationId': conversationId,
          'content': content,
          'type': 'text',
          if (clientMessageId != null) 'clientMessageId': clientMessageId,
        },
      }));
    } catch (e) {
      _eventController.add(ErrorEvent(message: 'Send failed: $e'));
    }
  }

  /// Send typing indicator
  void sendTyping({
    required String conversationId,
    required bool isTyping,
  }) {
    if (!isConnected) return;

    try {
      _channel!.sink.add(jsonEncode({
        'type': 'typing',
        'data': {
          'conversationId': conversationId,
          'state': isTyping ? 'typing' : 'stopped',
        },
      }));
    } catch (e) {
      // Silent fail for typing (non-critical)
    }
  }

  /// Subscribe to conversation room (receive messages for this conversation)
  void joinConversation(String conversationId) {
    if (!isConnected) {
      print('[WS-CLIENT] Not connected, cannot join conversation');
      return;
    }

    try {
      print('[WS-CLIENT] Joining conversation $conversationId');
      _channel!.sink.add(jsonEncode({
        'type': 'join_conversation',
        'data': {
          'conversationId': conversationId,
        },
      }));
    } catch (e) {
      print('[WS-CLIENT] Error joining conversation: $e');
    }
  }

  /// Parse backend message and emit typed event
  void _handleMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String);
      final type = json['type'] ?? '';
      final payload = json['payload'] ?? json['data'] ?? {};

      print('[WS-RECV] Received event type=$type messageId=${payload['message']?['id']}');

      switch (type) {
        case 'connected':
          print('[WS-RECV] ConnectedEvent: userId=${payload['userId']} connectionId=${payload['connectionId']}');
          _eventController.add(ConnectedEvent(
            userId: payload['userId']?.toString() ?? '',
            connectionId: payload['connectionId'] ?? '',
          ));
          break;

        case 'message:created':
          if (payload['message'] != null) {
            final msg = ChatMessage.fromServerJson(payload['message']);
            print('[WS-RECV] MessageCreatedEvent: id=${msg.id} convId=${msg.conversationId} from=${msg.senderId}');
            _eventController.add(MessageCreatedEvent(message: msg));
          }
          break;

        case 'delivered':
          _eventController.add(MessageDeliveredEvent(
            messageId: payload['messageId'] ?? '',
            recipientId: payload['recipientId'] ?? '',
            deliveredAt: DateTime.parse(payload['deliveredAt'] ?? DateTime.now().toIso8601String()),
          ));
          break;

        case 'read':
          _eventController.add(MessageReadEvent(
            messageId: payload['messageId'] ?? '',
            readByUserId: payload['readByUserId'] ?? '',
            readAt: DateTime.parse(payload['readAt'] ?? DateTime.now().toIso8601String()),
          ));
          break;

        case 'typing':
          _eventController.add(TypingEvent(
            conversationId: payload['conversationId'] ?? '',
            userId: payload['userId'] ?? '',
            isTyping: (payload['state'] ?? '') == 'typing',
          ));
          break;

        case 'error':
          _eventController.add(ErrorEvent(
            message: payload['message'] ?? json['message'] ?? 'Unknown error',
          ));
          break;

        default:
          // Silently ignore unknown event types for forward compatibility
          break;
      }
    } catch (e) {
      _eventController.add(ErrorEvent(message: 'Failed to parse message: $e'));
    }
  }

  /// Disconnect cleanly
  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
      _channel = null;
    } catch (e) {
      // Ignore errors on close
    }
  }

  /// Cleanup
  void dispose() {
    disconnect();
    _eventController.close();
  }
}
