import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/chat_repository.dart';
import '../data/chat_rest_client.dart';
import '../data/chat_socket_client.dart';
import '../data/upload_service.dart';
import '../domain/chat_entities.dart';
import '../domain/message_state_machine.dart';

/// Controller/Provider for chat UI state
/// 
/// Wraps repository and provides:
/// - Typed streams for UI consumption
/// - High-level actions (send, retry, load more, etc.)
/// - Clean error handling
/// - No UI logic (pure data orchestration)
class ChatController extends ChangeNotifier {
  final ChatRepository repository;

  // Current conversation context
  String? _currentConversationId;
  String get currentConversationId => _currentConversationId ?? '';

  // State streams
  StreamSubscription? _messageSubscription;
  StreamSubscription? _conversationSubscription;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _onlineSubscription;

  // Cache for UI
  final Map<String, List<ChatMessage>> _conversationMessages = {};
  final List<ConversationEntity> _conversations = [];
  List<ChatMessage> _currentQueue = [];
  bool _isOnline = true;

  // Error handling
  String? _lastError;

  // Getters for UI
  List<ConversationEntity> get conversations => List.unmodifiable(_conversations);
  List<ChatMessage> get currentMessages => 
      _conversationMessages[_currentConversationId] ?? [];
  List<ChatMessage> get offlineQueue => List.unmodifiable(_currentQueue);
  bool get isOnline => _isOnline;
  String? get lastError => _lastError;

  ChatController({required this.repository}) {
    _subscribeToState();
  }

  /// Initialize the controller
  Future<void> init() async {
    try {
      await repository.init();
    } catch (e) {
      _lastError = 'Failed to initialize: $e';
      notifyListeners();
    }
  }

  /// Load conversations
  Future<void> loadConversations() async {
    try {
      _lastError = null;
      final convos = await repository.getConversations();
      _conversations.clear();
      _conversations.addAll(convos);
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to load conversations: $e';
      notifyListeners();
    }
  }

  /// Set current conversation and load messages
  Future<void> setCurrentConversation(String conversationId) async {
    try {
      _lastError = null;
      _currentConversationId = conversationId;
      print('[CTRL] setCurrentConversation: $conversationId');

      if (!_conversationMessages.containsKey(conversationId)) {
        print('[CTRL] Loading messages for conversation: $conversationId');
        final messages = await repository.getMessages(conversationId: conversationId);
        _conversationMessages[conversationId] = messages;
        print('[CTRL] Loaded ${messages.length} messages');
      } else {
        print('[CTRL] Conversation already in cache: ${_conversationMessages[conversationId]!.length} messages');
        // CRITICAL FIX: Merge REST messages with any messages that may have arrived via WebSocket
        // while the conversation was being loaded. This prevents message loss due to race conditions.
        print('[CTRL] Refreshing from repository to ensure no WebSocket messages were missed...');
        final restMessages = await repository.getMessages(conversationId: conversationId);
        final existingMessages = _conversationMessages[conversationId]!;
        
        // Create a map of existing messages by ID
        final existingMap = {for (var msg in existingMessages) msg.id: msg};
        
        // Add any new messages from REST that aren't already in the list
        for (var msg in restMessages) {
          if (!existingMap.containsKey(msg.id)) {
            print('[CTRL] Adding REST message that wasn\'t in cache: ${msg.id}');
            existingMessages.add(msg);
          } else {
            // Update existing messages with fresh data from REST
            existingMap[msg.id] = msg;
          }
        }
        
        // Re-sort all messages
        existingMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        print('[CTRL] Merged cache and REST: now ${existingMessages.length} total messages');
      }

      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to load conversation messages: $e';
      notifyListeners();
    }
  }

  /// Send a text message
  Future<void> sendMessage(String content) async {
    if (_currentConversationId == null || _currentConversationId!.isEmpty) {
      _lastError = 'No conversation selected';
      notifyListeners();
      return;
    }

    try {
      _lastError = null;
      print('[CTRL] sendMessage: "$content" to conversation=$_currentConversationId');
      
      // Get current user ID from JWT token
      final userId = await getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        _lastError = 'Failed to get user ID';
        notifyListeners();
        return;
      }
      
      print('[CTRL] Sending message as userId=$userId');
      
      await repository.sendTextMessage(
        conversationId: _currentConversationId!,
        senderId: userId,
        content: content,
      );
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to send message: $e';
      notifyListeners();
    }
  }

  /// Subscribe to conversation room on WebSocket
  /// 
  /// Called when user navigates to a conversation to ensure real-time delivery
  void joinConversation(String conversationId) {
    try {
      print('[CTRL] joinConversation: $conversationId');
      repository.socket.joinConversation(conversationId);
    } catch (e) {
      print('[CTRL] Error joining conversation: $e');
      _lastError = 'Failed to subscribe to updates: $e';
      notifyListeners();
    }
  }

  /// Retry a failed message
  Future<void> retryMessage(String messageId) async {
    try {
      _lastError = null;
      await repository.retryMessage(messageId);
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to retry message: $e';
      notifyListeners();
    }
  }

  /// Process offline queue when coming back online
  Future<void> processQueue() async {
    try {
      _lastError = null;
      await repository.processOfflineQueue();
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to process queue: $e';
      notifyListeners();
    }
  }

  /// Subscribe to repository state changes
  void _subscribeToState() {
    _messageSubscription = repository.messageUpdated.listen((msg) {
      final convId = msg.conversationId;
      print('[CTRL] messageUpdated stream: id=${msg.id} convId=$convId');
      print('[CTRL] Current conversation: $_currentConversationId');
      print('[CTRL] Has conversation in store: ${_conversationMessages.containsKey(convId)}');
      
      // CRITICAL: Always ensure the conversation exists in the store
      // This handles race conditions where a message arrives before the conversation is explicitly loaded
      final messages = _conversationMessages.putIfAbsent(convId, () => []);
      print('[CTRL] Store has ${messages.length} messages before update');
      
      // If this is a canonical message with clientMessageId, remove optimistic version
      if (msg.clientMessageId != null && msg.clientMessageId!.isNotEmpty) {
        print('[CTRL] Removing optimistic: clientMsgId=${msg.clientMessageId}');
        messages.removeWhere((m) => m.clientMessageId == msg.clientMessageId);
      }
      
      // Replace or add the message
      final idx = messages.indexWhere((m) => m.id == msg.id);
      if (idx >= 0) {
        print('[CTRL] Replacing message at index $idx');
        messages[idx] = msg;
      } else {
        print('[CTRL] Adding new message');
        messages.add(msg);
      }
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      print('[CTRL] Store now has ${messages.length} messages after update');

      if (convId == _currentConversationId) {
        print('[CTRL] Current conversation updated, notifying listeners');
        notifyListeners();
      } else {
        print('[CTRL] Different conversation, not notifying');
      }
    });

    _conversationSubscription = repository.conversationUpdated.listen((conv) {
      final idx = _conversations.indexWhere((c) => c.id == conv.id);
      if (idx >= 0) {
        _conversations[idx] = conv;
      } else {
        _conversations.add(conv);
      }
      notifyListeners();
    });

    _queueSubscription = repository.queueChanged.listen((queue) {
      _currentQueue = queue;
      notifyListeners();
    });

    _onlineSubscription = repository.onlineStatusChanged.listen((isOnline) {
      _isOnline = isOnline;
      notifyListeners();

      if (isOnline) {
        processQueue();
      }
    });
  }

  /// Get list of available users to start conversations with
  Future<List<Map<String, dynamic>>> getAvailableUsers() async {
    try {
      _lastError = null;
      return await repository.getAvailableUsers();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Create a new conversation with another user
  Future<ConversationEntity?> createConversation(int userId) async {
    try {
      _lastError = null;
      final conversation = await repository.createConversation(user2Id: userId);
      notifyListeners();
      return conversation;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Get current user ID from JWT token
  Future<String?> getCurrentUserId() async {
    try {
      return await repository.getCurrentUserId();
    } catch (e) {
      print('Error getting current user ID: $e');
      return null;
    }
  }

  /// Mark current conversation as read
  Future<void> markConversationAsRead() async {
    if (_currentConversationId == null || _currentConversationId!.isEmpty) {
      return;
    }
    
    try {
      await repository.markConversationAsRead(_currentConversationId!);
    } catch (e) {
      print('Error marking conversation as read: $e');
      // Don't notify listeners - marking as read shouldn't affect UI
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _conversationSubscription?.cancel();
    _queueSubscription?.cancel();
    _onlineSubscription?.cancel();
    repository.dispose();
    super.dispose();
  }
}
