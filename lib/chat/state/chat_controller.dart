import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import '../data/chat_repository.dart';
import '../data/chat_rest_client.dart';
import '../data/chat_socket_client.dart';
import '../data/upload_service.dart';
import '../domain/chat_entities.dart';
import '../domain/message_state_machine.dart';
import '../../shared/models/employee_model.dart';
import '../../features/employees/services/employee_service.dart';

/// Controller/Provider for chat UI state
/// ...
class ChatController extends ChangeNotifier {
  final ChatRepository repository;

  // Cache for employee data (employeeId is userId)
  final Map<String, Employee> _employeeCache = {};
  Map<String, Employee> get employeeCache => _employeeCache;

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
  bool _isDisposed = false;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

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

  ChatController({required this.repository}) {
    _subscribeToState();
  }

  /// Initialize the controller
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Future.wait([
        repository.init(),
        loadEmployeeData(),
      ]);
      _isInitialized = true;
    } catch (e) {
      _lastError = 'Failed to initialize: $e';
      _safeNotifyListeners();
    }
  }

  /// Load employee data for avatar/name resolution
  Future<void> loadEmployeeData() async {
    try {
      print('[CTRL] loadEmployeeData: Fetching employees...');
      final employees = await EmployeeService.getAllEmployees();
      print('[CTRL] loadEmployeeData: Received ${employees.length} employees');
      
      for (final emp in employees) {
        if (emp.id != null) {
          _employeeCache[emp.id!] = emp;
          if (emp.avatarUrl != null || emp.photo != null) {
            print('[CTRL] Cached employee: id=${emp.id} hasAvatar=${emp.avatarUrl != null || emp.photo != null}');
          }
        }
      }
      print('[CTRL] Total employees in cache: ${_employeeCache.length}');
      _safeNotifyListeners();
    } catch (e) {
      print('[CTRL] Error loading employee data: $e');
    }
  }

  /// Resolve avatar for a given userId
  String? getAvatarForUser(String userId) {
    // 1. Check employee cache (primary source)
    if (_employeeCache.containsKey(userId)) {
      final avatar = _employeeCache[userId]!.avatarUrl;
      if (avatar != null && avatar.isNotEmpty) {
        // print('[CTRL] Resolved avatar for $userId: ${avatar.substring(0, avatar.length > 30 ? 30 : avatar.length)}...');
      }
      return avatar;
    }
    return null;
  }

  /// Resolve full name for a given userId
  String? getNameForUser(String userId) {
    if (_employeeCache.containsKey(userId)) {
      return _employeeCache[userId]!.fullName;
    }
    return null;
  }

  /// Load conversations
  Future<void> loadConversations() async {
    try {
      _lastError = null;
      final convos = await repository.getConversations();
      _conversations.clear();
      _conversations.addAll(convos);
      // Sort conversations so freshest is at top
      _conversations.sort((a, b) => (b.lastMessageAt ?? b.updatedAt).compareTo(a.lastMessageAt ?? a.updatedAt));
      for (final conv in convos) {
        print('📱 Conversation: ${conv.name}, avatarUrl: ${conv.avatarUrl}, type: ${conv.type}');
      }
      _safeNotifyListeners();
    } catch (e) {
      _lastError = 'Failed to load conversations: $e';
      _safeNotifyListeners();
    }
  }

  /// Set current conversation and load messages
  Future<void> setCurrentConversation(String conversationId) async {
    try {
      _lastError = null;
      _currentConversationId = conversationId;

      if (!_conversationMessages.containsKey(conversationId)) {
        // First open: fetch from server, show when ready
        final messages = await repository.getMessages(conversationId: conversationId);
        // Backend returns newest first, so we MUST sort or reverse to maintain [oldest...newest] internal order
        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _conversationMessages[conversationId] = messages;
        _safeNotifyListeners();
      } else {
        // Already cached: show immediately
        _safeNotifyListeners();
        // Then silently refresh in background to pick up any missed messages
        repository.getMessages(conversationId: conversationId).then((restMessages) {
          if (_isDisposed) return;
          final existing = _conversationMessages[conversationId]!;
          final existingIds = {for (var m in existing) m.id};
          bool changed = false;
          for (var msg in restMessages) {
            if (!existingIds.contains(msg.id)) {
              existing.add(msg);
              changed = true;
            }
          }
          if (changed) {
            existing.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _safeNotifyListeners();
          }
        }).catchError((_) {});
      }
    } catch (e) {
      _lastError = 'Failed to load conversation messages: $e';
      _safeNotifyListeners();
    }
  }

  /// Send a text message
  Future<void> sendMessage(String content) async {
    if (_currentConversationId == null || _currentConversationId!.isEmpty) {
      _lastError = 'No conversation selected';
      _safeNotifyListeners();
      return;
    }

    try {
      _lastError = null;
      print('[CTRL] sendMessage: "$content" to conversation=$_currentConversationId');
      
      // Get current user ID from JWT token
      final userId = await getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        _lastError = 'Failed to get user ID';
        _safeNotifyListeners();
        return;
      }
      
      print('[CTRL] Sending message as userId=$userId');
      
      await repository.sendTextMessage(
        conversationId: _currentConversationId!,
        senderId: userId,
        content: content,
      );
      _safeNotifyListeners();
    } catch (e) {
      _lastError = 'Failed to send message: $e';
      _safeNotifyListeners();
    }
  }

  /// Send message with attachments
  Future<void> sendMessageWithAttachments(String content, List<String> uploadIds, {Map<String, dynamic>? voiceMetadata, List<String>? localPaths}) async {
    if (_currentConversationId == null || _currentConversationId!.isEmpty) {
      _lastError = 'No conversation selected';
      _safeNotifyListeners();
      return;
    }

    try {
      _lastError = null;
      print('[CTRL] sendMessageWithAttachments: "$content" with ${uploadIds.length} attachments to conversation=$_currentConversationId');
      
      // Get current user ID from JWT token
      final userId = await getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        _lastError = 'Failed to get user ID';
        _safeNotifyListeners();
        return;
      }
      
      print('[CTRL] Sending message as userId=$userId');
      
      // Determine message type based on content and attachments
      String messageType = 'text';
      if (uploadIds.isNotEmpty) {
        // Use 'voice' type for voice attachments, 'file' for others
        messageType = voiceMetadata != null ? 'voice' : 'file';
      }
      
      await repository.sendMessageWithAttachments(
        conversationId: _currentConversationId!,
        senderId: userId,
        content: content,
        type: messageType,
        uploadIds: uploadIds,
        voiceMetadata: voiceMetadata,
        localPaths: localPaths,
      );
      _safeNotifyListeners();
    } catch (e) {
      _lastError = 'Failed to send message with attachments: $e';
      _safeNotifyListeners();
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
      _safeNotifyListeners();
    }
  }

  /// Retry a failed message
  Future<void> retryMessage(String messageId) async {
    try {
      _lastError = null;
      await repository.retryMessage(messageId);
      _safeNotifyListeners();
    } catch (e) {
      _lastError = 'Failed to retry message: $e';
      _safeNotifyListeners();
    }
  }

  /// Process offline queue when coming back online
  Future<void> processQueue() async {
    try {
      _lastError = null;
      await repository.processOfflineQueue();
      _safeNotifyListeners();
    } catch (e) {
      _lastError = 'Failed to process queue: $e';
      _safeNotifyListeners();
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
        print('[CTRL] Message count before notify: ${_conversationMessages[convId]?.length ?? 0}');
        _safeNotifyListeners();
        print('[CTRL] notifyListeners() called');
      } else {
        print('[CTRL] Different conversation, not notifying');
      }
    });

    _conversationSubscription = repository.conversationUpdated.listen((conv) {
      if (conv == null) {
        _safeNotifyListeners();
        return;
      }
      final idx = _conversations.indexWhere((c) => c.id == conv.id);
      if (idx >= 0) {
        _conversations[idx] = conv;
      } else {
        _conversations.add(conv);
      }
      _conversations.sort((a, b) => (b.lastMessageAt ?? b.updatedAt).compareTo(a.lastMessageAt ?? a.updatedAt));
      _safeNotifyListeners();
    });

    _queueSubscription = repository.queueChanged.listen((queue) {
      _currentQueue = queue;
      _safeNotifyListeners();
    });

    _onlineSubscription = repository.onlineStatusChanged.listen((isOnline) {
      _isOnline = isOnline;
      _safeNotifyListeners();

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
      _safeNotifyListeners();
      rethrow;
    }
  }

  /// Create a new conversation with another user (legacy support)
  Future<ConversationEntity?> createConversation(String userId) async {
    return createGroupConversation(
      participantIds: [userId],
      type: 'direct',
    );
  }

  /// Create a new group or direct conversation
  Future<ConversationEntity?> createGroupConversation({
    required List<String> participantIds,
    String type = 'group',
    String? name,
    String? avatarUrl,
  }) async {
    try {
      _lastError = null;
      final conversation = await repository.createConversation(
        participantIds: participantIds,
        type: type,
        name: name,
        avatarUrl: avatarUrl,
      );
      _safeNotifyListeners();
      return conversation;
    } catch (e) {
      _lastError = e.toString();
      _safeNotifyListeners();
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
      _safeNotifyListeners();
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
          _safeNotifyListeners();
          return null;
        }
      }
    } catch (e) {
      print('[CTRL] File validation error: $e');
      _lastError = 'Audio file not found at: $audioFilePath';
      _safeNotifyListeners();
      return null;
    }

    print('[CTRL] Final audioBytes count: ${audioBytes.length}');
    if (audioBytes.isEmpty && !kIsWeb) {
      _lastError = 'No audio data available for upload';
      print('[CTRL] ERROR: audioBytes is empty!');
      _safeNotifyListeners();
      return null;
    }

    if (durationMs <= 0) {
      _lastError = 'Invalid voice note duration';
      _safeNotifyListeners();
      return null;
    }

    try {
      _lastError = null;
      print('[CTRL] sendVoiceNote: conversationId=$_currentConversationId duration=${durationMs}ms fileSize=${audioBytes.length}');

      // Get current user ID
      final userId = await getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        _lastError = 'Failed to get user ID';
        _safeNotifyListeners();
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
        _safeNotifyListeners();
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

      print('[CTRL] Upload complete: uploadId=$uploadId serverUrl=${uploadResult.serverUrl}');

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
        localPaths: [audioFilePath], // Pass as list for consistency
      );

      print('[CTRL] Voice message sent successfully: ${message.id}');
      _safeNotifyListeners();
      return message;
    } catch (e) {
      _lastError = 'Failed to send voice note: $e';
      print('[CTRL-ERROR] $e');
      _safeNotifyListeners();
      rethrow;
    }
  }

  /// Fetch blob bytes for web audio files
  Future<List<int>> _fetchBlobBytes(String blobUrl) async {
    try {
      print('[CTRL] _fetchBlobBytes: Starting fetch for $blobUrl');
      
      // For blob URLs, we need to use dart:html to fetch the data
      final request = await html.HttpRequest.request(
        blobUrl,
        method: 'GET',
        responseType: 'arraybuffer',
      );
      
      print('[CTRL] _fetchBlobBytes: Response status: ${request.status}');
      print('[CTRL] _fetchBlobBytes: Response type: ${request.response.runtimeType}');
      
      if (request.status == 200) {
        final arrayBuffer = request.response as dynamic;
        print('[CTRL] _fetchBlobBytes: ArrayBuffer type: ${arrayBuffer.runtimeType}');
        
        if (arrayBuffer != null) {
          // Convert ArrayBuffer to List<int>
          final uint8List = Uint8List.view(arrayBuffer);
          final result = uint8List.toList();
          print('[CTRL] _fetchBlobBytes: Successfully converted ${result.length} bytes');
          return result;
        } else {
          print('[CTRL] _fetchBlobBytes: ArrayBuffer is null');
        }
      } else {
        print('[CTRL] _fetchBlobBytes: HTTP error ${request.status}');
      }
      return [];
    } catch (e) {
      print('[CTRL] _fetchBlobBytes error: $e');
      return [];
    }
  }

  /// Leave a conversation (delete for self)
  Future<void> leaveConversation(String conversationId) async {
    try {
      await repository.leaveConversation(conversationId);
      notifyListeners();
    } catch (e) {
      print('Error leaving conversation in controller: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messageSubscription?.cancel();
    _conversationSubscription?.cancel();
    _queueSubscription?.cancel();
    _onlineSubscription?.cancel();
    repository.dispose();
    super.dispose();
  }
}
