import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../domain/chat_entities.dart';
import '../domain/message_state_machine.dart';
import 'chat_rest_client.dart';
import 'chat_socket_client.dart';
import 'upload_service.dart';

/// Single source of truth for all chat state
/// 
/// Responsibilities:
/// - Merge messages from REST and WebSocket
/// - Manage offline queue
/// - Enforce state machine transitions
/// - Deduplication (clientMessageId → serverMessageId)
/// - Emit state changes as streams
/// - Handle retry logic
/// - Persist critical state (drafts, queue, scroll position)
class ChatRepository {
  final ChatRestClient rest;
  final ChatSocketClient socket;
  final UploadService uploads;

  /// In-memory message store (keyed by conversationId)
  final Map<String, Map<String, ChatMessage>> _messages = {};

  /// In-memory conversation list
  final List<ConversationEntity> _conversations = [];

  /// Offline message queue
  final List<ChatMessage> _offlineQueue = [];

  /// Map: clientMessageId → serverMessageId (for deduplication)
  final Map<String, String> _idempotencyMap = {};

  /// Streams
  final StreamController<ChatMessage> _messageUpdated = 
      StreamController<ChatMessage>.broadcast();
  final StreamController<ConversationEntity> _conversationUpdated =
      StreamController<ConversationEntity>.broadcast();
  final StreamController<List<ChatMessage>> _queueChanged =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<bool> _isOnlineChanged =
      StreamController<bool>.broadcast();

  bool _isOnline = true;

  /// Listen to message state changes
  Stream<ChatMessage> get messageUpdated => _messageUpdated.stream;

  /// Listen to conversation changes
  Stream<ConversationEntity> get conversationUpdated => _conversationUpdated.stream;

  /// Listen to queue changes
  Stream<List<ChatMessage>> get queueChanged => _queueChanged.stream;

  /// Listen to online/offline changes
  Stream<bool> get onlineStatusChanged => _isOnlineChanged.stream;

  bool get isOnline => _isOnline;

  ChatRepository({
    required this.rest,
    required this.socket,
    required this.uploads,
  });

  /// Initialize: connect socket, load initial state, listen for events
  Future<void> init() async {
    try {
      await socket.connect();
      _listenToSocketEvents();
    } catch (e) {
      _isOnline = false;
      _isOnlineChanged.add(false);
    }
  }

  /// Extract userId from JWT token
  /// JWT format: header.payload.signature
  /// Payload is base64-encoded JSON
  Future<String?> _extractUserIdFromToken() async {
    try {
      final token = await rest.tokenProvider();
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Add padding if necessary
      String payload = parts[1];
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');

      final decoded = utf8.decode(base64Url.decode(payload));
      final jsonPayload = jsonDecode(decoded);
      return jsonPayload['userId']?.toString();
    } catch (e) {
      print('Failed to extract userId from token: $e');
      return null;
    }
  }

  /// Get current user ID from JWT token (public method for UI)
  Future<String?> getCurrentUserId() => _extractUserIdFromToken();


  /// Fetch conversations list
  Future<List<ConversationEntity>> getConversations({int limit = 50}) async {
    try {
      _conversations.clear();
      final userId = await _extractUserIdFromToken();
      if (userId == null) {
        throw Exception('Unable to extract userId from token');
      }

      _conversations.addAll(await rest.getConversations(userId: userId, limit: limit));
      for (var c in _conversations) {
        _conversationUpdated.add(c);
      }
      return List.unmodifiable(_conversations);
    } catch (e) {
      throw Exception('Failed to fetch conversations: $e');
    }
  }

  /// Fetch messages for a conversation
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    int limit = 50,
  }) async {
    try {
      print('[REPO] getMessages: conversationId=$conversationId');
      final messages = await rest.getMessages(
        conversationId: conversationId,
        limit: limit,
      );

      print('[REPO] Fetched ${messages.length} messages from REST');
      
      // Store and deduplicate
      final store = _messages.putIfAbsent(conversationId, () => {});
      for (var msg in messages) {
        store[msg.id] = msg;
      }

      print('[REPO] Store now has ${store.length} messages for conversation');
      return messages;
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  /// Send a text message (online or queue for offline)
  /// 
  /// Process:
  /// 1. Create local optimistic message (state: draft)
  /// 2. Emit to UI immediately
  /// 3. If online: POST via REST with clientMessageId
  /// 4. If offline: add to queue
  /// 5. When server responds, transition to sent
  /// 6. When delivery receipt arrives via WS, transition to delivered
  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final clientId = const Uuid().v4();
    final now = DateTime.now();

    print('[REPO] sendTextMessage: conversationId=$conversationId senderId=$senderId');
    print('[REPO] Generated clientMessageId=$clientId');

    // Step 1: Create optimistic local message
    final message = ChatMessage(
      id: clientId, // Temporary; will be replaced by server ID
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      type: 'text',
      state: MessageState.draft,
      createdAt: now,
      updatedAt: now,
      clientMessageId: clientId,
    );

    // Step 2: Add to store and emit
    final store = _messages.putIfAbsent(conversationId, () => {});
    store[clientId] = message;
    print('[REPO] Added optimistic message: clientId=$clientId to store');
    _messageUpdated.add(message);

    // Step 3: Attempt send
    if (_isOnline) {
      try {
        // Transition: draft → sending
        var msg = message.copyWith(state: MessageState.sending);
        store[clientId] = msg;
        print('[REPO] Transitioning to sending: $clientId');
        _messageUpdated.add(msg);

        // POST to server
        print('[REPO] Posting message to REST endpoint...');
        final response = await rest.sendMessage(
          conversationId: conversationId,
          senderId: senderId,
          content: content,
          type: 'text',
          clientMessageId: clientId,
        );

        print('[REPO] REST response: serverId=${response.id} clientId=$clientId');
        
        // Replace optimistic message with server canonical
        _idempotencyMap[clientId] = response.id;
        store.remove(clientId);
        store[response.id] = response;
        print('[REPO] Replaced optimistic with canonical: ${response.id}');
        _messageUpdated.add(response);

        return response;
      } catch (e) {
        print('[REPO] Error sending message: $e');
        // Transition: sending → failed → queued
        var msg = message.copyWith(
          state: MessageState.queued,
          retryCount: 1,
        );
        store[clientId] = msg;
        _messageUpdated.add(msg);

        _offlineQueue.add(msg);
        _queueChanged.add(List.unmodifiable(_offlineQueue));
        
        return msg;
      }
    } else {
      print('[REPO] Offline: queuing message');
      // Transition: draft → queued
      var msg = message.copyWith(state: MessageState.queued);
      store[clientId] = msg;
      _messageUpdated.add(msg);

      _offlineQueue.add(msg);
      _queueChanged.add(List.unmodifiable(_offlineQueue));

      return msg;
    }
  }

  /// Retry a failed message
  Future<void> retryMessage(String messageId) async {
    final msg = _findMessageById(messageId);
    if (msg == null || !MessageStateMachine.canRetry(msg.state)) {
      return;
    }

    try {
      // Transition: failed → queued
      var updated = msg.copyWith(
        state: MessageState.queued,
        retryCount: msg.retryCount + 1,
      );

      _updateMessage(updated);

      // If online, try immediately
      if (_isOnline) {
        final response = await rest.sendMessage(
          conversationId: msg.conversationId,
          senderId: msg.senderId,
          content: msg.content,
          type: msg.type,
          clientMessageId: msg.clientMessageId,
        );

        _replaceMessageWithCanonical(msg.id, response);
      } else {
        // Queue for later
        _offlineQueue.add(updated);
        _queueChanged.add(List.unmodifiable(_offlineQueue));
      }
    } catch (e) {
      // Retry failed; stay in queued or transition to failed
      var failedMsg = msg.copyWith(state: MessageState.failed);
      _updateMessage(failedMsg);
    }
  }

  /// Process offline queue (called when network comes back online)
  Future<void> processOfflineQueue() async {
    if (!_isOnline || _offlineQueue.isEmpty) return;

    final queue = List.of(_offlineQueue);
    _offlineQueue.clear();

    for (var msg in queue) {
      try {
        final response = await rest.sendMessage(
          conversationId: msg.conversationId,
          senderId: msg.senderId,
          content: msg.content,
          type: msg.type,
          clientMessageId: msg.clientMessageId,
        );

        _replaceMessageWithCanonical(msg.id, response);
      } catch (e) {
        // Re-queue failed message
        _offlineQueue.add(msg.copyWith(retryCount: msg.retryCount + 1));
      }
    }

    _queueChanged.add(List.unmodifiable(_offlineQueue));
  }

  /// Listen to WebSocket events and apply state transitions
  void _listenToSocketEvents() {
    socket.events.listen((event) {
      if (event is ConnectedEvent) {
        print('[REPO] WebSocket connected: userId=${event.userId}');
        _isOnline = true;
        _isOnlineChanged.add(true);
        // Try to flush offline queue
        processOfflineQueue();
      } else if (event is MessageCreatedEvent) {
        final msg = event.message;
        print('[REPO] MessageCreatedEvent received: id=${msg.id} convId=${msg.conversationId}');
        
        // RUNTIME GUARD: Validate message structure
        if (msg.id.isEmpty) {
          print('[REPO-ERROR] ERROR: Received message with empty ID! conversationId=${msg.conversationId}');
          throw Exception('INVARIANT VIOLATION: Message ID is empty');
        }
        
        if (msg.conversationId.isEmpty) {
          print('[REPO-ERROR] ERROR: Received message with empty conversationId! id=${msg.id}');
          throw Exception('INVARIANT VIOLATION: Message conversationId is empty');
        }
        
        final store = _messages.putIfAbsent(msg.conversationId, () => {});
        
        // RUNTIME GUARD: Check for duplicate message IDs
        if (store.containsKey(msg.id)) {
          print('[REPO-WARN] WARNING: Duplicate message ID ${msg.id} in conversation ${msg.conversationId}');
          // Replace the existing message (idempotent operation)
        }
        
        // If message has clientMessageId, find and remove optimistic message
        if (msg.clientMessageId != null && msg.clientMessageId!.isNotEmpty) {
          print('[REPO] Deduplicating: removing optimistic clientMsgId=${msg.clientMessageId}');
          // Find and remove the optimistic message with this clientMessageId
          store.removeWhere((key, value) => value.clientMessageId == msg.clientMessageId);
          
          // Track the idempotency mapping for future reference
          _idempotencyMap[msg.clientMessageId!] = msg.id;
        }
        
        // Add the server message (replaces optimistic if found)
        store[msg.id] = msg;
        print('[REPO] Added message to store: convId=${msg.conversationId} id=${msg.id}');
        print('[REPO] Store now has ${store.length} messages for this conversation');
        _messageUpdated.add(msg);
      } else if (event is MessageDeliveredEvent) {
        _applyDeliveryReceipt(event.messageId, event.recipientId, event.deliveredAt);
      } else if (event is MessageReadEvent) {
        _applyReadReceipt(event.messageId, event.readByUserId, event.readAt);
      } else if (event is ErrorEvent) {
        _isOnline = false;
        _isOnlineChanged.add(false);
      }
    });
  }

  /// Apply delivery receipt (transition: sent → delivered)
  void _applyDeliveryReceipt(String messageId, String recipientId, DateTime deliveredAt) {
    final msg = _findMessageById(messageId);
    if (msg == null) return;

    var updated = msg.copyWith(
      state: MessageState.delivered,
      deliveryStatus: [
        ...msg.deliveryStatus,
        MessageDeliveryStatus(
          recipientId: recipientId,
          deliveredAt: deliveredAt,
        ),
      ],
    );

    _updateMessage(updated);
  }

  /// Apply read receipt (transition: delivered → read)
  void _applyReadReceipt(String messageId, String readByUserId, DateTime readAt) {
    final msg = _findMessageById(messageId);
    if (msg == null) return;

    final updated = msg.copyWith(
      state: MessageState.read,
      deliveryStatus: msg.deliveryStatus
          .map((d) => d.recipientId == readByUserId
              ? MessageDeliveryStatus(
                  recipientId: d.recipientId,
                  deliveredAt: d.deliveredAt,
                  readAt: readAt,
                )
              : d)
          .toList(),
    );

    _updateMessage(updated);
  }

  /// Find message by ID across all conversations
  ChatMessage? _findMessageById(String id) {
    for (var store in _messages.values) {
      if (store.containsKey(id)) return store[id];
    }
    return null;
  }

  /// Update message in store and emit
  void _updateMessage(ChatMessage msg) {
    final store = _messages[msg.conversationId];
    if (store != null) {
      store[msg.id] = msg;
      _messageUpdated.add(msg);
    }
  }

  /// Replace temporary message with server canonical
  void _replaceMessageWithCanonical(String tempId, ChatMessage canonical) {
    final store = _messages[canonical.conversationId];
    if (store != null) {
      store.remove(tempId);
      store[canonical.id] = canonical;
      _messageUpdated.add(canonical);
    }
  }

  /// Get all messages in conversation
  List<ChatMessage> getConversationMessages(String conversationId) {
    final store = _messages[conversationId] ?? {};
    final msgs = store.values.toList();
    msgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return msgs;
  }

  /// Get offline queue
  List<ChatMessage> getOfflineQueue() => List.unmodifiable(_offlineQueue);

  /// Get list of available users to start conversations with
  Future<List<Map<String, dynamic>>> getAvailableUsers() async {
    try {
      final userId = await _extractUserIdFromToken();
      if (userId == null) {
        throw Exception('Unable to extract userId from token');
      }
      
      return await rest.getAvailableUsers(excludeUserId: userId);
    } catch (e) {
      print('Error getting available users: $e');
      rethrow;
    }
  }

  /// Create a new conversation with another user
  Future<ConversationEntity?> createConversation({
    required int user2Id,
  }) async {
    try {
      final userId = await _extractUserIdFromToken();
      if (userId == null) {
        throw Exception('Unable to extract userId from token');
      }

      final result = await rest.createConversation(
        user1Id: int.parse(userId),
        user2Id: user2Id,
        type: 'direct',
      );

      if (result['success'] == true) {
        final conversationId = result['data']['conversationId'];
        
        // Load the new conversation (refresh the list)
        await getConversations();
        
        // Find and return the newly created conversation
        return _conversations.firstWhere(
          (c) => c.id.toString() == conversationId.toString(),
          orElse: () => ConversationEntity(
            id: conversationId.toString(),
            name: '',
            type: 'direct',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to create conversation');
      }
    } catch (e) {
      print('Error creating conversation: $e');
      rethrow;
    }
  }

  /// Mark all messages in a conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final userId = await _extractUserIdFromToken();
      if (userId == null) {
        throw Exception('Unable to extract userId from token');
      }

      await rest.markConversationAsRead(
        conversationId: conversationId,
        userId: userId,
      );
    } catch (e) {
      print('Error marking conversation as read: $e');
      // Don't rethrow - marking as read shouldn't block UI
    }
  }

  /// Cleanup
  void dispose() {
    _messageUpdated.close();
    _conversationUpdated.close();
    _queueChanged.close();
    _isOnlineChanged.close();
    socket.dispose();
    uploads.dispose();
  }
}
