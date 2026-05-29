import 'dart:async';

import 'package:fs_hub/features/chat/data/chat_repository.dart';
import 'package:fs_hub/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:fs_hub/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:fs_hub/features/chat/data/datasources/upload_datasource.dart';
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';
import 'package:fs_hub/shared/models/chat_models.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockChatRemoteDatasource extends Mock implements ChatRemoteDatasource {}

class MockChatSocketDatasource extends Mock implements ChatSocketDatasource {}

class MockUploadDatasource extends Mock implements UploadDatasource {}

class FakeChatRemoteDatasource extends ChatRemoteDatasource {
  FakeChatRemoteDatasource()
      : super(baseUrl: 'http://test', tokenProvider: () async => 'token');
}

class FakeUploadDatasource extends UploadDatasource {
  FakeUploadDatasource()
      : super(baseUrl: 'http://test', tokenProvider: () async => 'token');
}

/// In-memory chat repository for [ChatController] tests (streams + stubs).
class FakeChatRepository implements ChatRepository {
  FakeChatRepository() {
    socket = _FakeSocket();
    rest = FakeChatRemoteDatasource();
    uploads = FakeUploadDatasource();
  }

  @override
  late final _FakeSocket socket;
  @override
  late final ChatRemoteDatasource rest;
  @override
  late final UploadDatasource uploads;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _conversationController =
      StreamController<ConversationEntity>.broadcast();
  final _queueController = StreamController<List<ChatMessage>>.broadcast();
  final _onlineController = StreamController<bool>.broadcast();
  final _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _deletedController = StreamController<String>.broadcast();

  String? currentUserId = 'user-test-001';
  final Map<String, String> drafts = {};
  final List<String> joinedConversations = [];
  final List<ConversationEntity> conversations = [];

  @override
  Stream<ChatMessage> get messageUpdated => _messageController.stream;

  @override
  Stream<ConversationEntity> get conversationUpdated =>
      _conversationController.stream;

  @override
  Stream<List<ChatMessage>> get queueChanged => _queueController.stream;

  @override
  Stream<bool> get onlineStatusChanged => _onlineController.stream;

  @override
  Stream<Map<String, dynamic>> get presenceUpdated => _presenceController.stream;

  @override
  Stream<Map<String, dynamic>> get typingUpdated => _typingController.stream;

  @override
  Stream<String> get conversationDeleted => _deletedController.stream;

  void emitMessage(ChatMessage message) => _messageController.add(message);

  void emitTyping(Map<String, dynamic> data) => _typingController.add(data);

  void emitConversationDeleted(String conversationId) =>
      _deletedController.add(conversationId);

  @override
  Future<void> init() async {}

  @override
  Future<List<ConversationEntity>> getConversations() async =>
      List<ConversationEntity>.from(conversations);

  @override
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    int? limit,
    String? before,
  }) async =>
      [];

  @override
  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? clientMessageId,
  }) async {
    return ChatMessage(
      id: 'server-${DateTime.now().millisecondsSinceEpoch}',
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: 'Me',
      content: content,
      type: 'text',
      createdAt: DateTime.now(),
      isFromMe: true,
      state: MessageState.sent,
    );
  }

  @override
  Future<ChatMessage> sendMessageWithAttachments({
    required String conversationId,
    required String senderId,
    required String content,
    String type = 'text',
    required List<String> uploadIds,
    Map<String, dynamic>? voiceMetadata,
    String? clientMessageId,
  }) async {
    return ChatMessage(
      id: 'server-att-${DateTime.now().millisecondsSinceEpoch}',
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: 'Me',
      content: content,
      type: type,
      createdAt: DateTime.now(),
      isFromMe: true,
      state: MessageState.sent,
    );
  }

  @override
  Future<void> retryMessage(String messageId) async {}

  @override
  Future<void> processOfflineQueue() async {}

  @override
  Future<List<Map<String, dynamic>>> getAvailableUsers() async => [];

  @override
  Future<ConversationEntity?> createConversation({required String user2Id}) async =>
      null;

  @override
  Future<ConversationEntity?> createGroupConversation({
    required List<String> participantIds,
    required String name,
    String type = 'group',
  }) async =>
      null;

  @override
  Future<String?> getCurrentUserId() async => currentUserId;

  @override
  Future<void> markConversationAsRead(String conversationId) async {}

  @override
  Future<void> deleteConversation(String conversationId) async {}

  @override
  void sendTypingStatus(String conversationId, bool isTyping) {}

  @override
  Future<void> saveDraft(String conversationId, String content) async {
    drafts[conversationId] = content;
  }

  @override
  Future<Map<String, String>> loadDrafts() async => Map.from(drafts);

  @override
  Future<void> clearDraft(String conversationId) async {
    drafts.remove(conversationId);
  }

  @override
  void dispose() {
    _messageController.close();
    _conversationController.close();
    _queueController.close();
    _onlineController.close();
    _presenceController.close();
    _typingController.close();
    _deletedController.close();
  }
}

class _FakeSocket extends ChatSocketDatasource {
  _FakeSocket()
      : super(
          wsUrl: 'ws://test',
          apiBaseUrl: 'http://test',
          tokenProvider: () async => 'token',
        );

  final List<String> joined = [];

  @override
  bool get isConnected => true;

  @override
  String? get connectionId => 'conn-test';

  @override
  Future<void> connect() async {}

  @override
  void joinConversation(String conversationId) {
    joined.add(conversationId);
  }

  @override
  void disconnect() {}

  @override
  void dispose() {}
}
