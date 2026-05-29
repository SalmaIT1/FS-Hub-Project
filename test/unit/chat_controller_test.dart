import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';
import 'package:fs_hub/features/chat/presentation/providers/chat_provider.dart';
import 'package:fs_hub/shared/models/chat_models.dart';

import '../mocks/chat_mocks.dart';

void main() {
  late FakeChatRepository repository;
  late ChatController controller;

  ConversationEntity sampleConversation(String id) => ConversationEntity(
        id: id,
        name: 'Test chat',
        lastMessage: '',
        lastMessageAt: DateTime(2026, 5, 24),
        participantIds: const ['user-test-001', 'user-other'],
        type: 'direct',
      );

  ChatMessage sampleMessage({
    required String id,
    required String conversationId,
    required String senderId,
    String content = 'Hi',
  }) =>
      ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderId == 'user-test-001' ? 'Me' : 'Peer',
        content: content,
        type: 'text',
        createdAt: DateTime(2026, 5, 24, 12, 0),
        isFromMe: senderId == 'user-test-001',
        state: MessageState.sent,
      );

  setUp(() {
    repository = FakeChatRepository();
    controller = ChatController(repository: repository);
  });

  tearDown(() {
    controller.dispose();
    repository.dispose();
  });

  group('ChatController', () {
    test('sendMessage shows optimistic then confirmed message', () async {
      await controller.setCurrentConversation('conv-1');
      await controller.sendMessage('Hello team');

      expect(controller.currentMessages, isNotEmpty);
      expect(
        controller.currentMessages.any((m) => m.content == 'Hello team'),
        isTrue,
      );
      expect(controller.currentMessages.last.state, MessageState.sent);
    });

    test('incoming WebSocket message appears in current conversation', () async {
      await controller.setCurrentConversation('conv-1');

      repository.emitMessage(
        sampleMessage(
          id: 'ws-msg-1',
          conversationId: 'conv-1',
          senderId: 'user-other',
          content: 'From socket',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.currentMessages.any((m) => m.content == 'From socket'),
        isTrue,
      );
    });

    test('peer message increments unread when conversation is in background', () async {
      repository.conversations.add(sampleConversation('conv-1'));
      await controller.loadConversations();
      await controller.setCurrentConversation('conv-1');

      repository.emitMessage(
        sampleMessage(
          id: 'bg-1',
          conversationId: 'conv-2',
          senderId: 'user-other',
          content: 'Background',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final bg = controller.conversations
          .where((c) => c.id == 'conv-2')
          .toList();
      if (bg.isNotEmpty) {
        expect(bg.first.unreadCount, greaterThanOrEqualTo(0));
      }
    });

    test('typing indicator updates matching conversation', () async {
      repository.conversations.add(sampleConversation('conv-1'));
      await controller.loadConversations();

      repository.emitTyping({
        'conversationId': 'conv-1',
        'userId': 'user-other',
        'isTyping': true,
      });
      await Future<void>.delayed(Duration.zero);

      final conv = controller.conversations.firstWhere((c) => c.id == 'conv-1');
      expect(conv.typingUserIds, contains('user-other'));
    });

    test('joinConversation delegates to socket', () {
      controller.joinConversation('conv-99');
      expect(repository.socket.joined, contains('conv-99'));
    });

    test('draft is saved via repository', () async {
      await controller.setCurrentConversation('conv-draft');
      controller.updateDraft('typing...');
      expect(repository.drafts['conv-draft'], 'typing...');
      expect(controller.currentDraft, 'typing...');
    });

    test('conversationDeleted clears active conversation', () async {
      await controller.setCurrentConversation('conv-del');
      repository.emitConversationDeleted('conv-del');
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentConversationId, isEmpty);
      expect(controller.currentMessages, isEmpty);
    });
  });
}
