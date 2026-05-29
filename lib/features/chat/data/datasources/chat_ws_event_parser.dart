import 'package:fs_hub/shared/models/chat_models.dart';

/// Parsed WebSocket events from the chat server (testable, no I/O).
sealed class ChatWsEvent {
  const ChatWsEvent();
}

class ChatWsConnectionAck extends ChatWsEvent {
  const ChatWsConnectionAck(this.connectionId);
  final String connectionId;
}

class ChatWsOnlineChanged extends ChatWsEvent {
  const ChatWsOnlineChanged(this.isOnline);
  final bool isOnline;
}

class ChatWsIncomingMessage extends ChatWsEvent {
  const ChatWsIncomingMessage(this.message);
  final ChatMessage message;
}

class ChatWsMessageAck extends ChatWsEvent {
  const ChatWsMessageAck(this.clientMessageId);
  final String clientMessageId;
}

class ChatWsMessageFailed extends ChatWsEvent {
  const ChatWsMessageFailed({
    required this.clientMessageId,
    required this.errorMessage,
  });
  final String clientMessageId;
  final String errorMessage;
}

class ChatWsPresence extends ChatWsEvent {
  const ChatWsPresence(this.payload);
  final Map<String, dynamic> payload;
}

class ChatWsTyping extends ChatWsEvent {
  const ChatWsTyping(this.payload);
  final Map<String, dynamic> payload;
}

class ChatWsConversationDeleted extends ChatWsEvent {
  const ChatWsConversationDeleted(this.conversationId);
  final String conversationId;
}

class ChatWsServerError extends ChatWsEvent {
  const ChatWsServerError(this.message);
  final String message;
}

class ChatWsUnknown extends ChatWsEvent {
  const ChatWsUnknown(this.type);
  final String? type;
}

/// Maps raw JSON frames from the chat WebSocket into typed events.
class ChatWsEventParser {
  const ChatWsEventParser._();

  static List<ChatWsEvent> parse(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'connection_ack':
        return [
          ChatWsConnectionAck(json['connectionId']?.toString() ?? ''),
          const ChatWsOnlineChanged(true),
        ];
      case 'connected':
        return [const ChatWsOnlineChanged(true)];
      case 'online':
        return [const ChatWsOnlineChanged(true)];
      case 'offline':
        return [const ChatWsOnlineChanged(false)];
      case 'error':
        final clientMsgId = json['clientMessageId'] as String?;
        if (clientMsgId != null) {
          return [
            ChatWsMessageFailed(
              clientMessageId: clientMsgId,
              errorMessage: json['message'] as String? ?? 'Message failed to send',
            ),
          ];
        }
        return [ChatWsServerError(json['message'] as String? ?? 'Unknown error')];
      case 'message':
      case 'new_message':
      case 'message:created':
        final msg = _extractMessagePayload(json);
        return msg != null ? [ChatWsIncomingMessage(msg)] : const [];
      case 'message:ack':
        final clientMsgId = json['clientMessageId'] as String?;
        return clientMsgId != null ? [ChatWsMessageAck(clientMsgId)] : const [];
      case 'presence':
        final payload = json['payload'] ?? json['data'];
        return payload != null
            ? [ChatWsPresence(Map<String, dynamic>.from(payload as Map))]
            : const [];
      case 'typing':
        final payload = json['payload'] ?? json['data'];
        return payload != null
            ? [ChatWsTyping(Map<String, dynamic>.from(payload as Map))]
            : const [];
      case 'conversation:deleted':
        final payload = json['payload'];
        if (payload is Map && payload['conversationId'] != null) {
          return [
            ChatWsConversationDeleted(payload['conversationId'].toString()),
          ];
        }
        return const [];
      default:
        return [ChatWsUnknown(type)];
    }
  }

  static ChatMessage? _extractMessagePayload(Map<String, dynamic> json) {
    dynamic msgData = json['message'] ?? json['data'];
    if (msgData == null && json['payload'] != null) {
      final payload = json['payload'];
      if (payload is Map) {
        msgData = payload['message'] ?? payload;
      }
    }
    if (msgData is! Map) return null;
    final msg = Map<String, dynamic>.from(msgData);
    msg['isFromMe'] = msg['isFromMe'] ?? false;
    return ChatMessage.fromJson(msg);
  }
}
