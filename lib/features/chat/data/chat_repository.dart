import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:fs_hub/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:fs_hub/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:fs_hub/features/chat/data/datasources/upload_datasource.dart';
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';

abstract class ChatRepository {
  ChatRemoteDatasource get rest;
  ChatSocketDatasource get socket;
  UploadDatasource get uploads;
  
  Stream<ChatMessage> get messageUpdated;
  Stream<ConversationEntity> get conversationUpdated;
  Stream<List<ChatMessage>> get queueChanged;
  Stream<bool> get onlineStatusChanged;
  Stream<Map<String, dynamic>> get presenceUpdated;
  Stream<Map<String, dynamic>> get typingUpdated;
  Stream<String> get conversationDeleted;

  Future<void> init();
  Future<List<ConversationEntity>> getConversations();
  Future<List<ChatMessage>> getMessages({required String conversationId, int? limit, String? before});
  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? clientMessageId,
  });
  Future<ChatMessage> sendMessageWithAttachments({
    required String conversationId,
    required String senderId,
    required String content,
    String type = 'text',
    required List<String> uploadIds,
    Map<String, dynamic>? voiceMetadata,
    String? clientMessageId,
  });
  Future<void> retryMessage(String messageId);
  Future<void> processOfflineQueue();
  Future<List<Map<String, dynamic>>> getAvailableUsers();
  Future<ConversationEntity?> createConversation({required String user2Id});
  Future<ConversationEntity?> createGroupConversation({
    required List<String> participantIds,
    required String name,
    String type = 'group',
  });
  Future<String?> getCurrentUserId();
  Future<void> markConversationAsRead(String conversationId);
  Future<void> deleteConversation(String conversationId);
  void sendTypingStatus(String conversationId, bool isTyping);
  Future<void> saveDraft(String conversationId, String content);
  Future<Map<String, String>> loadDrafts();
  Future<void> clearDraft(String conversationId);
  void dispose();
}

class ChatRepositoryImpl implements ChatRepository {
  @override
  final ChatRemoteDatasource rest;
  @override
  final ChatSocketDatasource socket;
  @override
  final UploadDatasource uploads;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _conversationController = StreamController<ConversationEntity>.broadcast();
  final _queueController = StreamController<List<ChatMessage>>.broadcast();
  final _onlineController = StreamController<bool>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationDeletedController = StreamController<String>.broadcast();

  final List<ChatMessage> _offlineQueue = [];
  bool _isOnline = true;
  final List<StreamSubscription> _subscriptions = [];

  ChatRepositoryImpl({
    required this.rest,
    required this.socket,
    required this.uploads,
  });

  // P1-02 FIX: Queue Persistence Layer
  // Saves the offline queue to a local JSON file to prevent message loss 
  // if the application crashes or is closed while some messages are still pending.
  Future<void> _persistQueue() async {
    if (kIsWeb) return; // path_provider not available on web
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/chat_offline_queue.json');
      final jsonList = _offlineQueue.map((msg) => msg.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('[REPO] Failed to persist offline queue: $e');
    }
  }

  // P3 FIX: Draft Persistence Logic
  Future<void> _saveDraftsToDisk(Map<String, String> drafts) async {
    if (kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/chat_drafts.json');
      await file.writeAsString(jsonEncode(drafts));
    } catch (e) {
      print('[REPO] Failed to persist drafts: $e');
    }
  }

  Future<Map<String, String>> _loadDraftsFromDisk() async {
    if (kIsWeb) return {};
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/chat_drafts.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return Map<String, String>.from(jsonDecode(content));
      }
    } catch (e) {
      print('[REPO] Failed to load drafts: $e');
    }
    return {};
  }

  Future<void> _loadQueue() async {
    if (kIsWeb) return; // path_provider not available on web
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/chat_offline_queue.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonList = jsonDecode(content) as List<dynamic>;
        _offlineQueue.clear();
        _offlineQueue.addAll(jsonList.map((j) => ChatMessage.fromJson(j as Map<String, dynamic>)));
        _queueController.add(List.unmodifiable(_offlineQueue));
        print('[REPO] Restored ${_offlineQueue.length} messages from persistent queue.');
      }
    } catch (e) {
      print('[REPO] Failed to load offline queue: $e');
    }
  }

  @override
  Stream<ChatMessage> get messageUpdated => _messageController.stream;
  @override
  Stream<ConversationEntity> get conversationUpdated => _conversationController.stream;
  @override
  Stream<List<ChatMessage>> get queueChanged => _queueController.stream;
  @override
  Stream<bool> get onlineStatusChanged => _onlineController.stream;
  @override
  Stream<Map<String, dynamic>> get presenceUpdated => _presenceController.stream;
  @override
  Stream<Map<String, dynamic>> get typingUpdated => _typingController.stream;
  @override
  Stream<String> get conversationDeleted => _conversationDeletedController.stream;

  @override
  Future<void> init() async {
    await _loadQueue();
    await socket.connect();
    
    _subscriptions.add(socket.messageStream.listen((msg) {
      if (!_messageController.isClosed) _messageController.add(msg);
    }));

    _subscriptions.add(socket.onlineStream.listen((isOnline) {
      final wasOffline = !_isOnline;
      _isOnline = isOnline;
      if (!_onlineController.isClosed) _onlineController.add(isOnline);
      
      // Automatically process queue when coming back online
      if (isOnline && wasOffline && _offlineQueue.isNotEmpty) {
        print('[REPO] Connection restored. Processing ${_offlineQueue.length} queued messages...');
        processOfflineQueue();
      }
    }));
    
    _subscriptions.add(socket.presenceStream.listen((data) {
      if (!_presenceController.isClosed) _presenceController.add(data);
    }));
    
    _subscriptions.add(socket.typingStream.listen((data) {
      if (!_typingController.isClosed) _typingController.add(data);
    }));

    _subscriptions.add(socket.conversationEventStream.listen((event) {
      if (event['type'] == 'deleted' && event['conversationId'] != null) {
        if (!_conversationDeletedController.isClosed) {
          _conversationDeletedController.add(event['conversationId'].toString());
        }
      }
    }));
  }

  @override
  Future<List<ConversationEntity>> getConversations() {
    return rest.getConversations();
  }

  @override
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    int? limit,
    String? before,
  }) {
    return rest.getMessages(
      conversationId: conversationId,
      limit: limit,
      before: before,
    );
  }

  @override
  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? clientMessageId,
  }) async {
    if (!_isOnline) {
      // Queue message for later
      final msg = ChatMessage(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: senderId,
        senderName: 'You',
        content: content,
        type: 'text',
        createdAt: DateTime.now(),
        isFromMe: true,
        state: MessageState.queued, // Explicitly set to queued
      );
      _offlineQueue.add(msg);
      _persistQueue();
      _queueController.add(List.unmodifiable(_offlineQueue));
      return msg;
    }

    final message = await rest.sendTextMessage(
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      clientMessageId: clientMessageId,
      excludeConnectionId: socket.connectionId,
    );
    
    if (!_messageController.isClosed) _messageController.add(message);
    return message;
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
  }) {
    return rest.sendMessageWithAttachments(
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      type: type,
      uploadIds: uploadIds,
      voiceMetadata: voiceMetadata,
      clientMessageId: clientMessageId,
      excludeConnectionId: socket.connectionId,
    ).then((msg) {
      if (!_messageController.isClosed) _messageController.add(msg);
      return msg;
    });
  }

  @override
  Future<void> retryMessage(String messageId) async {
    final msgIndex = _offlineQueue.indexWhere((m) => m.id == messageId);
    if (msgIndex >= 0) {
      final msg = _offlineQueue[msgIndex];
      _offlineQueue.removeAt(msgIndex);
      _persistQueue();
      _queueController.add(List.unmodifiable(_offlineQueue));
      
      await rest.sendTextMessage(
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        content: msg.content ?? '',
      );
    }
  }

  @override
  Future<void> processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    final messages = List<ChatMessage>.from(_offlineQueue);
    _offlineQueue.clear();
    _queueController.add([]);
    
    for (final msg in messages) {
      try {
        await rest.sendTextMessage(
          conversationId: msg.conversationId,
          senderId: msg.senderId,
          content: msg.content ?? '',
          clientMessageId: msg.id,
        );
      } catch (e) {
        print('Failed to send queued message: $e');
        _offlineQueue.add(msg);
      }
    }
    
    _persistQueue();
    _queueController.add(List.unmodifiable(_offlineQueue));
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableUsers() {
    return rest.getAvailableUsers();
  }

  @override
  Future<ConversationEntity?> createConversation({required String user2Id}) {
    return rest.createConversation(user2Id: user2Id);
  }

  @override
  Future<ConversationEntity?> createGroupConversation({
    required List<String> participantIds,
    required String name,
    String type = 'group',
  }) {
    return rest.createGroupConversation(
      participantIds: participantIds,
      name: name,
      type: type,
    );
  }

  @override
  Future<String?> getCurrentUserId() {
    return rest.getCurrentUserId();
  }

  @override
  Future<void> markConversationAsRead(String conversationId) {
    return rest.markConversationAsRead(conversationId);
  }

  @override
  Future<void> deleteConversation(String conversationId) {
    return rest.deleteConversation(conversationId);
  }

  @override
  void sendTypingStatus(String conversationId, bool isTyping) {
    socket.sendTypingIndicator(conversationId, isTyping);
  }

  @override
  Future<void> saveDraft(String conversationId, String content) async {
    final drafts = await loadDrafts();
    if (content.isEmpty) {
      drafts.remove(conversationId);
    } else {
      drafts[conversationId] = content;
    }
    await _saveDraftsToDisk(drafts);
  }

  @override
  Future<Map<String, String>> loadDrafts() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/chat_drafts.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        return map.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      print('[REPO] Failed to load drafts: $e');
    }
    return {};
  }

  @override
  Future<void> clearDraft(String conversationId) async {
    final drafts = await loadDrafts();
    if (drafts.containsKey(conversationId)) {
      drafts.remove(conversationId);
      await _saveDraftsToDisk(drafts);
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    
    _messageController.close();
    _conversationController.close();
    _queueController.close();
    _onlineController.close();
    _typingController.close();
    _presenceController.close();
    _conversationDeletedController.close();
  }
}
