import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/chat/domain/message_state_machine.dart';
import 'package:fs_hub/chat/domain/chat_entities.dart';

void main() {
  group('MessageStateMachine', () {
    test('draft transits to queued', () {
      expect(
        MessageStateMachine.canTransition(MessageState.draft, MessageState.queued),
        true,
      );
    });

    test('queued transits to sending or uploading', () {
      expect(
        MessageStateMachine.canTransition(MessageState.queued, MessageState.sending),
        true,
      );
      expect(
        MessageStateMachine.canTransition(MessageState.queued, MessageState.uploading),
        true,
      );
    });

    test('sending transits to sent or failed', () {
      expect(
        MessageStateMachine.canTransition(MessageState.sending, MessageState.sent),
        true,
      );
      expect(
        MessageStateMachine.canTransition(MessageState.sending, MessageState.failed),
        true,
      );
    });

    test('sent transits to delivered or read', () {
      expect(
        MessageStateMachine.canTransition(MessageState.sent, MessageState.delivered),
        true,
      );
      expect(
        MessageStateMachine.canTransition(MessageState.sent, MessageState.read),
        true,
      );
    });

    test('delivered transits to read only', () {
      expect(
        MessageStateMachine.canTransition(MessageState.delivered, MessageState.read),
        true,
      );
      expect(
        MessageStateMachine.canTransition(MessageState.delivered, MessageState.sent),
        false,
      );
    });

    test('failed transits to queued (retry)', () {
      expect(
        MessageStateMachine.canTransition(MessageState.failed, MessageState.queued),
        true,
      );
    });

    test('invalid transitions throw', () {
      expect(
        () => MessageStateMachine.transition(
          MessageState.read,
          MessageState.draft,
          'invalid',
        ),
        throwsStateError,
      );
    });

    test('isSent returns true for sent, delivered, read', () {
      expect(MessageStateMachine.isSent(MessageState.sent), true);
      expect(MessageStateMachine.isSent(MessageState.delivered), true);
      expect(MessageStateMachine.isSent(MessageState.read), true);
      expect(MessageStateMachine.isSent(MessageState.draft), false);
      expect(MessageStateMachine.isSent(MessageState.queued), false);
    });

    test('canRetry returns true only for failed', () {
      expect(MessageStateMachine.canRetry(MessageState.failed), true);
      expect(MessageStateMachine.canRetry(MessageState.draft), false);
      expect(MessageStateMachine.canRetry(MessageState.sent), false);
    });
  });

  group('ChatMessage', () {
    test('fromServerJson parses message correctly', () {
      final json = {
        'id': '123',
        'conversationId': 'conv-1',
        'senderId': 'user-1',
        'senderName': 'Alice',
        'content': 'Hello',
        'type': 'text',
        'createdAt': '2026-02-08T22:00:00Z',
        'updatedAt': '2026-02-08T22:00:00Z',
        'isRead': false,
      };

      final msg = ChatMessage.fromServerJson(json);

      expect(msg.id, '123');
      expect(msg.conversationId, 'conv-1');
      expect(msg.senderId, 'user-1');
      expect(msg.content, 'Hello');
      expect(msg.type, 'text');
      expect(msg.state, MessageState.sent); // Server messages are always sent
      expect(msg.senderName, 'Alice');
    });

    test('copyWith creates new instance with updates', () {
      final msg1 = ChatMessage(
        id: '1',
        conversationId: 'conv-1',
        senderId: 'user-1',
        content: 'Hello',
        type: 'text',
        state: MessageState.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final msg2 = msg1.copyWith(state: MessageState.queued, retryCount: 1);

      expect(msg1.state, MessageState.draft);
      expect(msg2.state, MessageState.queued);
      expect(msg2.retryCount, 1);
      expect(msg1.id, msg2.id); // ID unchanged
    });

    test('equality based on ID', () {
      final msg1 = ChatMessage(
        id: '1',
        conversationId: 'conv-1',
        senderId: 'user-1',
        content: 'Hello',
        type: 'text',
        state: MessageState.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final msg2 = ChatMessage(
        id: '1',
        conversationId: 'conv-2', // Different conversation
        senderId: 'user-2', // Different sender
        content: 'World', // Different content
        type: 'text',
        state: MessageState.sent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(msg1, msg2); // Same ID = equal
    });

    test('toJson includes all fields', () {
      final msg = ChatMessage(
        id: '1',
        conversationId: 'conv-1',
        senderId: 'user-1',
        content: 'Test',
        type: 'text',
        state: MessageState.sent,
        createdAt: DateTime(2026, 2, 8),
        updatedAt: DateTime(2026, 2, 8),
        clientMessageId: 'client-1',
        retryCount: 2,
      );

      final json = msg.toJson();

      expect(json['id'], '1');
      expect(json['clientMessageId'], 'client-1');
      expect(json['retryCount'], 2);
      expect(json['state'], MessageState.sent.toString());
    });
  });

  group('AttachmentEntity', () {
    test('fromJson parses attachment', () {
      final json = {
        'id': 'att-1',
        'conversationId': 'conv-1',
        'messageId': 'msg-1',
        'filename': 'photo.jpg',
        'mimeType': 'image/jpeg',
        'size': 2048,
        'uploadUrl': 'https://storage.example.com/photo.jpg',
        'uploadedAt': '2026-02-08T22:00:00Z',
      };

      final att = AttachmentEntity.fromJson(json);

      expect(att.id, 'att-1');
      expect(att.filename, 'photo.jpg');
      expect(att.mimeType, 'image/jpeg');
      expect(att.size, 2048);
    });
  });

  group('ConversationEntity', () {
    test('fromServerJson parses conversation', () {
      final json = {
        'id': 'conv-1',
        'name': 'Team Chat',
        'type': 'group',
        'createdAt': '2026-02-08T20:00:00Z',
        'updatedAt': '2026-02-08T22:00:00Z',
        'unreadCount': 5,
        'isArchived': false,
      };

      final conv = ConversationEntity.fromServerJson(json);

      expect(conv.id, 'conv-1');
      expect(conv.name, 'Team Chat');
      expect(conv.type, 'group');
      expect(conv.unreadCount, 5);
      expect(conv.isArchived, false);
    });

    test('copyWith updates fields', () {
      final conv1 = ConversationEntity(
        id: 'conv-1',
        name: 'Chat',
        type: 'direct',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        unreadCount: 5,
      );

      final conv2 = conv1.copyWith(unreadCount: 0);

      expect(conv1.unreadCount, 5);
      expect(conv2.unreadCount, 0);
      expect(conv2.name, 'Chat'); // Unchanged
    });
  });
}
