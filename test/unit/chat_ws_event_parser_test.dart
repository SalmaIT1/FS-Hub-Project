import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/features/chat/data/datasources/chat_ws_event_parser.dart';
import 'package:fs_hub/shared/models/chat_models.dart';

void main() {
  group('ChatWsEventParser', () {
    test('parses connection_ack and marks online', () {
      final events = ChatWsEventParser.parse({
        'type': 'connection_ack',
        'connectionId': 'conn-abc',
      });
      expect(events, [
        isA<ChatWsConnectionAck>().having((e) => e.connectionId, 'id', 'conn-abc'),
        isA<ChatWsOnlineChanged>().having((e) => e.isOnline, 'online', true),
      ]);
    });

    test('parses new_message payload', () {
      final events = ChatWsEventParser.parse({
        'type': 'new_message',
        'message': {
          'id': 'msg-1',
          'conversationId': 'conv-1',
          'senderId': 'user-2',
          'senderName': 'Alice',
          'content': 'Hello',
          'type': 'text',
          'createdAt': '2026-05-24T10:00:00.000Z',
        },
      });
      expect(events.length, 1);
      final msg = (events.first as ChatWsIncomingMessage).message;
      expect(msg.id, 'msg-1');
      expect(msg.content, 'Hello');
      expect(msg.isFromMe, isFalse);
    });

    test('parses message:ack', () {
      final events = ChatWsEventParser.parse({
        'type': 'message:ack',
        'clientMessageId': 'client-99',
      });
      expect(events.single, isA<ChatWsMessageAck>());
      expect((events.single as ChatWsMessageAck).clientMessageId, 'client-99');
    });

    test('maps error with clientMessageId to failed state', () {
      final events = ChatWsEventParser.parse({
        'type': 'error',
        'clientMessageId': 'client-err',
        'message': 'Rate limited',
      });
      expect(events.single, isA<ChatWsMessageFailed>());
    });

    test('parses typing payload', () {
      final events = ChatWsEventParser.parse({
        'type': 'typing',
        'payload': {
          'conversationId': 'conv-1',
          'userId': 'user-2',
          'isTyping': true,
        },
      });
      expect(events.single, isA<ChatWsTyping>());
      final payload = (events.single as ChatWsTyping).payload;
      expect(payload['conversationId'], 'conv-1');
    });

    test('parses conversation:deleted', () {
      final events = ChatWsEventParser.parse({
        'type': 'conversation:deleted',
        'payload': {'conversationId': 'conv-del'},
      });
      expect(events.single, isA<ChatWsConversationDeleted>());
      expect(
        (events.single as ChatWsConversationDeleted).conversationId,
        'conv-del',
      );
    });

    test('unknown type returns ChatWsUnknown', () {
      final events = ChatWsEventParser.parse({'type': 'future_event'});
      expect(events.single, isA<ChatWsUnknown>());
    });
  });
}
