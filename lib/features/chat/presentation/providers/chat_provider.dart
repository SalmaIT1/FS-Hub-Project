import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/chat_repository.dart';
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';

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
  StreamSubscription? _presenceSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _conversationDeletedSubscription;

  // Cache for UI
  final Map<String, List<ChatMessage>> _conversationMessages = {};
  final List<ConversationEntity> _conversations = [];
  List<ChatMessage> _currentQueue = [];
  bool _isOnline = true;

  // Error handling
  String? _lastError;

  // Getters for UI
  List<ConversationEntity> get conversations => List.unmodifiable(_conversations);
  List<ChatMessage> get currentMessages {
    final msgs = _conversationMessages[_currentConversationId] ?? [];
    print('[CTRL] currentMessages getter: convId=$_currentConversationId, count=${msgs.length}');
    return msgs;
  }
  List<ChatMessage> get offlineQueue => List.unmodifiable(_currentQueue);
  bool get isOnline => _isOnline;
  String? get lastError => _lastError;

  ConversationEntity? get currentConversation {
    if (_currentConversationId == null) return null;
    try {
      return _conversations.firstWhere((c) => c.id == _currentConversationId);
    } catch (_) {
      return null;
    }
  }

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
        notifyListeners();
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
      
      final message = await repository.sendTextMessage(
        conversationId: _currentConversationId!,
        senderId: userId,
        content: content,
      );
      
      // Manually update cache to ensure immediate UI refresh
      _handleMessageUpdate(message);
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to send message: $e';
      notifyListeners();
    }
  }

  /// Send message with attachments
  Future<void> sendMessageWithAttachments(String content, List<String> uploadIds, {Map<String, dynamic>? voiceMetadata}) async {
    if (_currentConversationId == null || _currentConversationId!.isEmpty) {
      _lastError = 'No conversation selected';
      notifyListeners();
      return;
    }

    try {
      _lastError = null;
      print('[CTRL] sendMessageWithAttachments: "$content" with ${uploadIds.length} attachments to conversation=$_currentConversationId');
      
      // Get current user ID from JWT token
      final userId = await getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        _lastError = 'Failed to get user ID';
        notifyListeners();
        return;
      }
      
      print('[CTRL] Sending message as userId=$userId');
      
      // Determine message type based on content and attachments
      String messageType = 'text';
      if (uploadIds.isNotEmpty) {
        // Use 'voice' type for voice attachments, 'file' for others
        messageType = voiceMetadata != null ? 'voice' : 'file';
      }
      
      final message = await repository.sendMessageWithAttachments(
        conversationId: _currentConversationId!,
        senderId: userId,
        content: content,
        type: messageType,
        uploadIds: uploadIds,
        voiceMetadata: voiceMetadata,
      );
      
      // Manually update cache to ensure immediate UI refresh
      _handleMessageUpdate(message);
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to send message with attachments: $e';
      notifyListeners();
    }
  }

  /// Subscribe to conversation room on WebSocket
  /// 
  /// Called when user navigates to a conversation to ensure real-time delivery
  void joinConversation(String conversationId) {
    try {

      repository.socket.joinConversation(conversationId);
    } catch (e) {

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
      _handleMessageUpdate(msg);
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

    _presenceSubscription = repository.presenceUpdated.listen((data) {
      final userId = data['userId']?.toString();
      final status = data['state']?.toString();
      final isOnline = status == 'online';
      
      bool updated = false;
      for (int i = 0; i < _conversations.length; i++) {
        final conv = _conversations[i];
        if (conv.type == 'direct' && conv.participantIds.contains(userId)) {
          _conversations[i] = conv.copyWith(isOnline: isOnline);
          updated = true;
        }
      }
      if (updated) notifyListeners();
    });

    _typingSubscription = repository.typingUpdated.listen((data) {
      final conversationId = data['conversationId']?.toString();
      final userId = data['userId']?.toString();
      final isTyping = data['isTyping'] == true || data['state'] == 'typing';
      
      if (conversationId != null && userId != null) {
        final idx = _conversations.indexWhere((c) => c.id == conversationId);
        if (idx >= 0) {
          final conv = _conversations[idx];
          final typingUserIds = List<String>.from(conv.typingUserIds);
          if (isTyping) {
            if (!typingUserIds.contains(userId)) {
              typingUserIds.add(userId);
              _conversations[idx] = conv.copyWith(typingUserIds: typingUserIds);
              notifyListeners();
            }
          } else {
            if (typingUserIds.contains(userId)) {
              typingUserIds.remove(userId);
              _conversations[idx] = conv.copyWith(typingUserIds: typingUserIds);
              notifyListeners();
            }
          }
        }
      }
    });

    _conversationDeletedSubscription = repository.conversationDeleted.listen((conversationId) {
      _conversations.removeWhere((c) => c.id == conversationId);
      _conversationMessages.remove(conversationId);
      if (_currentConversationId == conversationId) {
        _currentConversationId = null;
      }
      notifyListeners();
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
  Future<ConversationEntity?> createConversation(String userId) async {
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

  /// Create a group conversation with multiple participants
  Future<ConversationEntity?> createGroupConversation({
    required List<String> participantIds,
    required String name,
    String type = 'group',
  }) async {
    try {
      _lastError = null;
      final conversation = await repository.createGroupConversation(
        participantIds: participantIds,
        name: name,
        type: type,
      );
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

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      await repository.deleteConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      _conversationMessages.remove(conversationId);
      if (_currentConversationId == conversationId) {
        _currentConversationId = null;
      }
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to delete conversation: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Send typing status for the current conversation
  void setTypingStatus(bool isTyping) {
    if (_currentConversationId != null) {
      repository.sendTypingStatus(_currentConversationId!, isTyping);
    }
  }

  /// Send a voice note
  /// 
  /// Complete pipeline:
  /// 1. Request signed URL from backend
  /// 2. Upload audio file to signed URL  
  /// 3. Send message with upload ID
  /// 4. Emit state updates for UI
  Future<ChatMessage?> sendVoiceNote({
    required String audioFilePath,
    required List<int> audioBytes,
    required int durationMs,
    required String waveformData,
    void Function(double)? onUploadProgress,
  }) async {
    print('[CTRL] sendVoiceNote called: file=$audioFilePath, bytes=${audioBytes.length}, duration=$durationMs');
    print('[CTRL] DEBUG: kIsWeb = $kIsWeb');
    print('[CTRL] DEBUG: audioFilePath starts with blob: ${audioFilePath.startsWith('blob:')}');
    
    if (_currentConversationId == null || _currentConversationId!.isEmpty) {
      _lastError = 'No conversation selected';
      notifyListeners();
      return null;
    }

    // CRITICAL VALIDATION: Ensure file exists and has content
    try {
      if (kIsWeb && audioFilePath.startsWith('blob:')) {
        // Web: Handle blob URLs - upload service will fetch
        print('[CTRL] Web blob detected: $audioFilePath');
        print('[CTRL] Initial audioBytes count: ${audioBytes.length}');
        
        // For web, upload service will handle blob fetching
        // Just validate that we have a blob URL
        if (audioBytes.isEmpty) {
          print('[CTRL] Web mode - allowing empty bytes for blob URL');
        }
      } else {
        // Desktop/Mobile: Check file system
        final file = await File(audioFilePath).stat();
        print('[CTRL] File stat: size=${file.size}');
        if (file.size == 0) {
          _lastError = 'Audio file is empty (0 bytes) - cannot upload';
          notifyListeners();
          return null;
        }
      }
    } catch (e) {
      print('[CTRL] File validation error: $e');
      _lastError = 'Audio file not found at: $audioFilePath';
      notifyListeners();
      return null;
    }

    print('[CTRL] Final audioBytes count: ${audioBytes.length}');
    if (audioBytes.isEmpty && !kIsWeb) {
      _lastError = 'No audio data available for upload';
      print('[CTRL] ERROR: audioBytes is empty!');
      notifyListeners();
      return null;
    }

    if (durationMs <= 0) {
      _lastError = 'Invalid voice note duration';
      notifyListeners();
      return null;
    }

    try {
      _lastError = null;
      print('[CTRL] sendVoiceNote: conversationId=$_currentConversationId duration=${durationMs}ms fileSize=${audioBytes.length}');

      // Get current user ID
      final userId = await getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        _lastError = 'Failed to get user ID';
        notifyListeners();
        return null;
      }

      // Step 1: Request signed URL from backend
      print('[CTRL] Requesting signed URL for voice upload...');
      print('[CTRL] Uploading file with size: ${audioBytes.length}');
      final signedUrlResponse = await repository.rest.requestSignedUrl(
        contentType: 'audio/aac',
        filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        fileSize: audioBytes.length, // MUST be actual file length
      );

      final uploadId = signedUrlResponse['uploadId'] as String?;
      final signedUrl = signedUrlResponse['uploadUrl'] as String? ?? 
                        signedUrlResponse['signedUrl'] as String?;

      if (uploadId == null || uploadId.isEmpty || signedUrl == null || signedUrl.isEmpty) {
        _lastError = 'Failed to get upload URL from server';
        notifyListeners();
        return null;
      }

      print('[CTRL] Got uploadId=$uploadId, uploading to signed URL...');

      // Step 2: Upload audio file to signed URL
      final audioFile = File(audioFilePath);
      final uploadResult = await repository.uploads.uploadVoiceNote(
        uploadId: uploadId,
        signedUrl: signedUrl,
        audioFile: audioFile,
        durationMs: durationMs,
        waveformData: waveformData,
        onProgress: onUploadProgress,
      );

      print('[CTRL] Upload complete: uploadId=$uploadId serverUrl=${uploadResult['serverUrl']}');

      // Step 3: Send message with upload ID
      print('[CTRL] Sending message with uploadId=$uploadId...');
      final durationSeconds = durationMs / 1000.0;
      final message = await repository.sendMessageWithAttachments(
        conversationId: _currentConversationId!,
        senderId: userId,
        content: '', // Voice notes don't have text content
        type: 'voice', // Set type to 'voice' for voice note messages
        uploadIds: [uploadId],
        voiceMetadata: {
          'duration_seconds': durationSeconds,
          'waveform_data': waveformData,
        },
      );

      print('[CTRL] Voice message sent successfully: ${message.id}');
      notifyListeners();
      return message;
    } catch (e) {
      _lastError = 'Failed to send voice note: $e';
      print('[CTRL-ERROR] $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Logout and cleanup
  Future<void> logout() async {
    repository.dispose();
    _conversationMessages.clear();
    _conversations.clear();
    _currentQueue.clear();
    _currentConversationId = null;
    notifyListeners();
  }

  /// Internal helper to process message updates from any source (Socket or REST)
  void _handleMessageUpdate(ChatMessage msg) {
    final convId = msg.conversationId;
    print('[CTRL] _handleMessageUpdate: id=${msg.id} convId=$convId');
    
    // CRITICAL: Always ensure the conversation exists in the store
    final messages = _conversationMessages.putIfAbsent(convId, () => []);
    
    // If this is a canonical message with clientMessageId, remove optimistic version
    if (msg.clientMessageId != null && msg.clientMessageId!.isNotEmpty) {
      messages.removeWhere((m) => m.clientMessageId == msg.clientMessageId);
    }
    
    // Replace or add the message
    final idx = messages.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      messages[idx] = msg;
    } else {
      messages.add(msg);
    }
    
    // Re-sort all messages by date
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (convId == _currentConversationId) {
      notifyListeners();
    } else {
      // If message is for a convo not in our list, reload it
      if (!_conversations.any((c) => c.id == convId)) {
        loadConversations();
      } else {
        notifyListeners(); // Update unread counts in list
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _conversationSubscription?.cancel();
    _queueSubscription?.cancel();
    _onlineSubscription?.cancel();
    _presenceSubscription?.cancel();
    _typingSubscription?.cancel();
    _conversationDeletedSubscription?.cancel();
    super.dispose();
  }
}

