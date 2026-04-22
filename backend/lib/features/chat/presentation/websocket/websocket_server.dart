import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/database/connection.dart';
import '../../domain/services/chat_service.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../../../core/services/redis_service.dart';

const _uuid = Uuid();

class WebSocketServer {
  static WebSocketServer? _instance;
  final bool _isDisposed = false;

  WebSocketServer._internal() {
    _presenceBroadcastController.stream.listen(_handlePresenceBroadcast);
    
    // P1 SURGICAL FIX: Hook into Redis backplane for cross-instance broadcasting
    RedisService().messageStream.listen((data) {
      if (data['type'] == 'fshub:broadcast:room') {
        _sendToConversationLocal(data['conversationId'], data['message'], excludeConnectionId: data['excludeConnectionId']);
      } else if (data['type'] == 'fshub:broadcast:user') {
        _sendToUserLocal(data['userId'], data['message']);
      }
    });
  }

  // Store connections as dynamic to support both `dart:io.WebSocket`
  // and `package:web_socket_channel`'s WebSocketChannel used by some clients.
  final Map<String, dynamic> _connections = {};
  static final Map<String, List<String>> _mutualUsersCache = {};
  static final Map<String, DateTime> _mutualUsersCacheTime = {};
  static final Map<String, List<String>> _conversationMembersCache = {};
  static final Map<String, DateTime> _conversationMembersCacheTime = {};

  // P1 FIX: Presence broadcast stream for decoupling
  final StreamController<Map<String, dynamic>> _presenceBroadcastController = StreamController.broadcast();

  final Map<String, String> _userConnections = {};
  final Map<String, Set<String>> _userToConnections = {};
  final Map<String, Set<String>> _conversationRooms = {};
  Timer? _cleanupTimer;

  /// Invalidate presence caches for multiple users
  static void invalidatePresenceCache(List<String> userIds) {
    for (final id in userIds) {
      _mutualUsersCache.remove(id);
      _mutualUsersCacheTime.remove(id);
    }
  }

  /// Invalidate conversation member cache
  static void invalidateConversationCache(String conversationId) {
    _conversationMembersCache.remove(conversationId);
    _conversationMembersCacheTime.remove(conversationId);
  }

  WebSocketServer() {
    _instance = this;
  }

  /// Get the singleton instance for broadcasting
  static WebSocketServer? get instance => _instance;

  Router get router {
    return Router()
      // WebSocket endpoint: requires a short-lived one-time ticket obtained from
      // POST /v1/auth/ws-ticket. Never put long-lived JWTs in the URL.
      // H-2 FIX: Removed legacy /ws?token=JWT path — JWTs in URLs are logged
      // by servers and proxies. All clients must use the ticket-based flow.
      ..get('/', _chatHandler)
      ..get('/chat', _chatHandler)
      ..all('/<ignored|.*>', _chatHandler); // Catch-all for the mount point if needed
  }

  FutureOr<Response> _chatHandler(Request request) {
    // Accept ticket from query parameter (short-lived, one-time use).
    final ticket = request.url.queryParameters['ticket'];
    if (ticket == null || ticket.isEmpty) {
      return Future.value(Response(
        401,
        body: jsonEncode({'error': 'Unauthorized', 'message': 'WS ticket required'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      ));
    }

    // Consume and validate the one-time ticket.
    final identity = AuthService.consumeWsTicket(ticket);
    if (identity == null) {
      return Future.value(Response(
        403,
        body: jsonEncode({'error': 'Forbidden', 'message': 'Invalid or expired ticket'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      ));
    }

    final userId = identity['userId']!;
    final handler = webSocketHandler((dynamic webSocket) {
      _registerConnection(webSocket, userId);
    });
    return handler(request);
  }



  void _registerConnection(dynamic webSocket, String userId) {
    final connectionId = _uuid.v4();

    print('[WS-REGISTER] userId=$userId connectionId=$connectionId');

    // Store connection
    _connections[connectionId] = webSocket;
    _userConnections[connectionId] = userId; 
    _userToConnections.putIfAbsent(userId, () => {}).add(connectionId);
    
    // P1 SURGICAL FIX: Sync presence with Redis backplane
    RedisService().setUserOnline(userId, connectionId);

    // Send welcome message
    _sendToConnection(connectionId, {
      'type': 'connected',
      'data': {'userId': userId, 'connectionId': connectionId},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Update presence in DB and broadcast
    _updateUserPresence(userId, true);

    // Handle messages
    _attachListeners(connectionId, userId, webSocket);
  }

  void _attachListeners(String connectionId, String userId, dynamic webSocket) {
    try {
      if (webSocket is WebSocket) {
        webSocket.listen(
          (message) => _handleMessage(connectionId, userId, message),
          onError: (error) {
            print('[WS-ERROR] Connection $connectionId error: $error');
            _handleDisconnection(connectionId, userId);
          },
          onDone: () {
            print('[WS-DONE] Connection $connectionId closed by client');
            _handleDisconnection(connectionId, userId);
          },
          cancelOnError: true,
        );
      } else {
        // WebSocketChannel from web_socket_channel package
        webSocket.stream.listen(
          (message) => _handleMessage(connectionId, userId, message),
          onError: (error) {
            print('[WS-ERROR] Connection $connectionId error: $error');
            _handleDisconnection(connectionId, userId);
          },
          onDone: () {
            print('[WS-DONE] Connection $connectionId closed by client');
            _handleDisconnection(connectionId, userId);
          },
          cancelOnError: true,
        );
      }
    } catch (e) {
      print('[WS-LISTENER-ERROR] Failed to attach listener: $e');
      _handleDisconnection(connectionId, userId);
    }
  }

  Future<void> _handleMessage(String connectionId, String userId, String message) async {
    try {
      final json = jsonDecode(message);
      final String type = json['type'] ?? '';
      
      // Robust payload extraction: check both root level and nested 'data' object
      final Map<String, dynamic> payload = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {};
      
      // Merge root properties into payload for better backward/cross compatibility
      json.forEach((key, value) {
        if (key != 'type' && key != 'data') {
          payload[key] = value;
        }
      });
      
      switch (type) {
        case 'ping':
          _handlePing(connectionId, userId);
          break;
        
        case 'join':
        case 'join_conversation':
          _handleJoinConversation(connectionId, userId, payload);
          break;
          
        case 'message':
            // M-5 FIX: Enforce content size limit on incoming WS messages.
            final content = payload['content']?.toString() ?? '';
            if (content.length > 10000) {
              _sendError(connectionId, 'Message content exceeds 10,000 characters');
              break;
            }
            _handleChatMessage(connectionId, userId, payload);
          break;

        case 'message:ack':
          // ACK protocol: client confirms it received a message.
          final ackedId = payload['messageId']?.toString() ?? payload['message_id']?.toString();
          if (ackedId != null) {
            // P1.3 FIX: Await the ACK to ensure persistence and handle potential failures
            await ChatService.markMessagesAsRead(messageIds: [ackedId], userId: userId);
          }
          print('[WS-ACK] userId=$userId acked messageId=$ackedId');
          break;
          
        case 'typing':
          _handleTyping(connectionId, userId, payload);
          break;
          
        case 'presence':
          _handlePresence(connectionId, userId, payload);
          break;
          
        case 'file_upload_start':
          _handleFileUpload(connectionId, userId, payload);
          break;
          
        default:
          print('[WS-MESSAGE] Unknown message type: $type');
      }
    } catch (e) {
      print('[WS-MESSAGE-ERROR] Error handling WebSocket message: $e');
      _sendError(connectionId, 'Failed to process message: $e');
    }
  }

  /// Broadcasts a notification to a specific user
  static void broadcastNotification(String userId, Map<String, dynamic> notification) {
    final instance = _instance;
    if (instance == null) return;
    
    final message = {
      'type': 'notification',
      'payload': notification,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 1. Send to local connections
    instance._sendToUserLocal(userId, message);
    
    // 2. Publish to Redis for other instances
    RedisService().publish('fshub:events', {
      'type': 'fshub:broadcast:user',
      'userId': userId,
      'message': message,
    });
  }

  void _sendToUserLocal(String userId, Map<String, dynamic> message) {
    final connections = _userToConnections[userId];
    if (connections != null) {
      for (final connId in connections) {
        _sendToConnection(connId, message);
      }
    }
  }

  void _handlePing(String connectionId, String userId) {
    _sendToConnection(connectionId, {
      'type': 'pong',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _handleChatMessage(String connectionId, String userId, Map<String, dynamic> messageData) async {
    try {
      final result = await ChatService.sendMessage(
        conversationId: messageData['conversationId'],
        senderId: userId,
        content: messageData['content'],
        type: messageData['type'],
        replyToId: messageData['replyToId'],
        clientMessageId: messageData['clientMessageId'],
        excludeConnectionId: connectionId, // Pass this to prevent echo to sender
      );

      if (!result['success']) {
        _sendError(connectionId, result['message']);
      } else {
        // P0 FIX: Push message:ack back to the sender connection properly to prevent UI deadlock
        _sendToConnection(connectionId, {
          'type': 'message:ack',
          'clientMessageId': messageData['clientMessageId'],
          'serverMessage': result['message']
        });
      }
      // Note: No manual broadcast needed here. ChatService.sendMessage 
      // already triggers the broadcast to all eligible participants.
    } catch (e) {
      print('Error handling chat message: $e');
      _sendError(connectionId, 'Failed to send message: $e');
    }
  }

  void _handleTyping(String connectionId, String userId, Map<String, dynamic> typingData) async {
    try {
      final conversationId = typingData['conversationId'];
      // Frontend sends state: 'typing'|'stopped'; convert to isTyping boolean
      final state = typingData['state'] ?? typingData['isTyping'];
      final isTyping = (state == 'typing') || (state == true);
      
      final result = await ChatService.setTypingIndicator(
        conversationId: conversationId,
        userId: userId,
        isTyping: isTyping,
      );

      if (result['success']) {
        // Broadcast typing indicator to other participants
        await _broadcastToConversation(
          conversationId,
          {
            'type': 'typing',
            'payload': {
              'conversationId': conversationId,
              'userId': userId,
              'state': isTyping ? 'typing' : 'stopped',
            },
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          excludeConnectionId: connectionId,
        );
      }
    } catch (e) {
      print('Error handling typing indicator: $e');
    }
  }

  void _handlePresence(String connectionId, String userId, Map<String, dynamic> presenceData) async {
    // Handle presence updates (online/away/busy)
    final state = presenceData['state'] ?? 'online';
    await _updateUserPresence(userId, state == 'online', explicitState: state);
  }

  Future<void> _updateUserPresence(String userId, bool isOnline, {String? explicitState}) async {
    try {
      final conn = DBConnection.getConnection();
      final state = explicitState ?? (isOnline ? 'online' : 'offline');
      
      // 1. Update users table
      await conn.execute(
        'UPDATE users SET is_online = :isOnline, last_seen = NOW() WHERE id = :userId',
        {'isOnline': isOnline ? 1 : 0, 'userId': userId}
      );

      // 2. Find all unique users who share any conversation with this user
      List<String>? members = _mutualUsersCache[userId];
      final cacheTime = _mutualUsersCacheTime[userId];

      // Cache for 30 seconds (reduced from 60 for better reactivity)
      if (members == null || cacheTime == null || DateTime.now().difference(cacheTime).inSeconds > 30) {
        // P2-02 FIX: LRU-style cache eviction to prevent unbounded memory growth.
        // If cache exceeds 1000 entries, evict the oldest entry.
        if (_mutualUsersCache.length > 1000) {
          final oldestKey = _mutualUsersCacheTime.entries
              .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
              .key;
          _mutualUsersCache.remove(oldestKey);
          _mutualUsersCacheTime.remove(oldestKey);
        }

        final membersRes = await conn.execute('''
          SELECT DISTINCT cm2.user_id 
          FROM conversation_members cm1
          JOIN conversation_members cm2 ON cm1.conversation_id = cm2.conversation_id
          WHERE cm1.user_id = :userId 
          AND cm2.user_id != :userId 
          AND cm1.left_at IS NULL
          AND cm2.left_at IS NULL
        ''', {'userId': userId});
        members = membersRes.rows.map((row) => row.colByName('user_id')?.toString() ?? '').where((id) => id.isNotEmpty).toList();
        _mutualUsersCache[userId] = members;
        _mutualUsersCacheTime[userId] = DateTime.now();
      }

      // 3. Queue broadcast via stream
      _presenceBroadcastController.add({
        'userId': userId,
        'state': state,
        'members': members,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

    } catch (e) {
      print('[WS-PRESENCE-ERROR] Failed to update presence for $userId: $e');
    }
  }

  /// P1 FIX: Decoupled broadcast handler
  void _handlePresenceBroadcast(Map<String, dynamic> data) {
    final userId = data['userId'] as String;
    final state = data['state'] as String;
    final members = data['members'] as List<String>;
    final timestamp = data['timestamp'] as int;

    final event = {
      'type': 'presence',
      'payload': {
        'userId': userId,
        'state': state,
        'lastSeen': timestamp,
      },
      'timestamp': timestamp,
    };

    int reached = 0;
    for (final otherUserId in members) {
      if (otherUserId.isEmpty) continue;
      final connections = _userToConnections[otherUserId];
      if (connections != null) {
        for (final connId in connections) {
          _sendToConnection(connId, event);
          reached++;
        }
      }
    }
    if (reached > 0) {
      print('[WS-PRESENCE-BROADCAST] userId=$userId is $state. Reached $reached connections.');
    }
  }

  void _handleFileUpload(String connectionId, String userId, Map<String, dynamic> uploadData) {
    // File uploads happen via REST (POST /v1/uploads). Notify client to use REST.
    _sendToConnection(connectionId, {
      'type': 'info',
      'message': 'Use POST /v1/uploads/signed-url then PUT to upload files.',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _broadcastToConversation(
    String conversationId,
    Map<String, dynamic> message, {
    String? excludeConnectionId,
  }) async {
    try {
      // 1. Send to local connections
      await _sendToConversationLocal(conversationId, message, excludeConnectionId: excludeConnectionId);
      
      // 2. Publish to Redis backplane for other instances
      RedisService().publish('fshub:events', {
        'type': 'fshub:broadcast:room',
        'conversationId': conversationId,
        'message': message,
        'excludeConnectionId': excludeConnectionId,
      });
      
    } catch (e) {
      print('[WS-BROADCAST-ERROR] Error broadcasting to conversation: $e');
    }
  }

  Future<void> _sendToConversationLocal(
    String conversationId,
    Map<String, dynamic> message, {
    String? excludeConnectionId,
  }) async {
      // P1-ARCHITECTURE FIX: Utilize _conversationRooms for efficient O(1) broadcasting
      // to active participants. Non-active members (online but not in room) are still 
      // reached via the legacy fallback to ensure unread count increments.
      final roomKey = 'conv_$conversationId';
      final activeConnections = _conversationRooms[roomKey] ?? {};
      
      // We still need the full member list to reach participants NOT in the room (for unread counts)
      final members = await _getConversationMembers(conversationId);
      final processedConnections = <String>{};

      for (final memberId in members) {
        final connections = _userToConnections[memberId];
        if (connections == null) continue;

        for (final connId in connections) {
          if (connId == excludeConnectionId) continue;
          if (processedConnections.contains(connId)) continue;

          _sendToConnection(connId, message);
          processedConnections.add(connId);
        }
      }
      
      // Safety check: ensure any mystery connection in the room (not caught by membership loop) gets it
      for (final connId in activeConnections) {
        if (connId == excludeConnectionId) continue;
        if (!processedConnections.contains(connId)) {
          _sendToConnection(connId, message);
        }
      }
      print('[WS-BROADCAST-LOCAL] Sent ${message['type']} to conversation $conversationId');
  }

  Future<List<String>> _getConversationMembers(String conversationId) async {
    var members = _conversationMembersCache[conversationId];
    final cacheTime = _conversationMembersCacheTime[conversationId];
    
    if (members == null || cacheTime == null || DateTime.now().difference(cacheTime).inSeconds > 60) {
      final conn = DBConnection.getConnection();
      final membersRes = await conn.execute(
        '''
        SELECT cm.user_id 
        FROM conversation_members cm
        JOIN conversations c ON cm.conversation_id = c.id
        WHERE cm.conversation_id = :conversationId 
        AND (c.type = 'direct' OR cm.left_at IS NULL)
        ''',
        {'conversationId': conversationId}
      );
      members = membersRes.rows.map((row) => row.colByName('user_id')?.toString() ?? '').where((id) => id.isNotEmpty).toList();
      _conversationMembersCache[conversationId] = members;
      _conversationMembersCacheTime[conversationId] = DateTime.now();
    }
    return members;
  }

  void _sendToConnection(String connectionId, Map<String, dynamic> message) {
    final connection = _connections[connectionId];
    if (connection != null) {
      try {
        final jsonMessage = jsonEncode(message);
        // P3-5 FIX: Use a try/sink.add first (web_socket_channel style),
        // fall back to direct .add() (dart:io WebSocket style).
        // The previous toString().contains() check was fragile against package updates.
        try {
          connection.sink.add(jsonMessage);
        } catch (_) {
          connection.add(jsonMessage);
        }
      } catch (e) {
        print('Error sending to connection $connectionId: $e');
        _handleDisconnection(connectionId, _userConnections[connectionId]?.toString() ?? '');
      }
    }
  }

  void _sendError(String connectionId, String error) {
    _sendToConnection(connectionId, {
      'type': 'error',
      'message': error,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }



  void _handleDisconnection(String connectionId, String userId) {
    print('[WS-DISCONNECT] userId=$userId, connectionId=$connectionId');
    
    // Remove connection and update tracking
    _connections.remove(connectionId);
    _userConnections.remove(connectionId);
    _userToConnections[userId]?.remove(connectionId);
    if (_userToConnections[userId]?.isEmpty ?? false) {
      _userToConnections.remove(userId);
    }
    
    // P1 SURGICAL FIX: Sync presence with Redis backplane
    RedisService().setUserOffline(userId, connectionId);

    // P2 FIX: Evict the conversation member cache for all rooms this
    // connection was subscribed to, so subsequent broadcasts use fresh
    // membership data rather than serving the departed user.
    final emptyRooms = <String>[];
    for (final entry in _conversationRooms.entries) {
      entry.value.remove(connectionId);
      if (entry.value.isEmpty) {
        emptyRooms.add(entry.key);
      } else {
        // Still has active members — invalidate the cached list so the next
        // _getConversationMembers() call fetches the authoritative DB view.
        final convId = entry.key.replaceFirst('conv_', '');
        invalidateConversationCache(convId);
      }
    }
    for (final key in emptyRooms) {
      _conversationRooms.remove(key);
    }
    
    // If this was the last connection for this user, mark as offline
    final remainingConnections = _userToConnections[userId]?.length ?? 0;
    if (userId.isNotEmpty && remainingConnections == 0) {
      _updateUserPresence(userId, false);
    }
    
    print('[WS-DISCONNECT] Cleanup complete for userId=$userId. Remaining users: ${_userToConnections.keys.toSet()}');
  }

  void _handleJoinConversation(String connectionId, String userId, Map<String, dynamic> data) async {
    try {
      final conversationId = data['conversationId']?.toString();
      if (conversationId == null || conversationId.isEmpty) {
        print('[WS-ROOM] ERROR: No conversationId provided');
        _sendError(connectionId, 'conversationId is required');
        return;
      }

      // H-3 FIX: Verify the user is actually a member of this conversation
      // before allowing them to subscribe to its real-time events.
      final conn = DBConnection.getConnection();
      final memberCheck = await conn.execute(
        'SELECT id FROM conversation_members WHERE conversation_id = :convId AND user_id = :userId AND left_at IS NULL',
        {'convId': conversationId, 'userId': userId},
      );
      if (memberCheck.rows.isEmpty) {
        print('[WS-ROOM] FORBIDDEN: User $userId is not a member of conversation $conversationId');
        _sendError(connectionId, 'You are not a member of this conversation');
        return;
      }

      final roomKey = 'conv_$conversationId';
      _conversationRooms.putIfAbsent(roomKey, () => {}).add(connectionId);
      
      print('[WS-ROOM] User $userId joined conversation $conversationId (room=$roomKey)');
      print('[WS-ROOM] Room now has ${_conversationRooms[roomKey]?.length ?? 0} subscribers');
    } catch (e) {
      print('[WS-ROOM-ERROR] Failed to join room: $e');
      _sendError(connectionId, 'Failed to join room: $e');
    }
  }



  /// Static method for broadcasting from REST API handlers
  /// Broadcasts a message to all connected participants in a conversation
  static Future<void> broadcastToConversationMembers(
    String conversationId,
    Map<String, dynamic> message, {
    String? excludeUserId,
    String? excludeConnectionId,
  }) async {
    print('[WS-BROADCAST-STATIC] broadcastToConversationMembers called for conv=$conversationId');
    final instance = _instance;
    if (instance == null) {
      print('[WS-BROADCAST-STATIC] ERROR: WebSocketServer instance is null!');
      return;
    }
    
    try {
      // If a specific connectionId is provided, use it (device-level exclusion).
      // Otherwise fall back to user-level exclusion for REST-initiated broadcasts.
      String? resolvedExcludeConnId = excludeConnectionId;
      if (resolvedExcludeConnId == null && excludeUserId != null) {
        // REST path: exclude ALL connections of the sender user (they sent via REST,
        // so their WS clients should still receive it — but to preserve backward
        // compatibility, we honour the legacy excludeUserId here).
        final userConnIds = instance._userToConnections[excludeUserId];
        if (userConnIds != null && userConnIds.length == 1) {
          resolvedExcludeConnId = userConnIds.first;
        }
        // If user has multiple connections, we do NOT exclude any — all devices receive.
      }

      print('[WS-BROADCAST-STATIC] Calling instance._broadcastToConversation...');
      await instance._broadcastToConversation(
        conversationId,
        message,
        excludeConnectionId: resolvedExcludeConnId,
      );
      print('[WS-BROADCAST-STATIC] broadcastToConversationMembers completed');
    } catch (e) {
      print('[WS-BROADCAST-STATIC] Error broadcasting message: $e');
    }
  }

  void startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cleanupDeadConnections();
    });
  }

  void _cleanupDeadConnections() {
    final deadConnections = <String>[];
    
    for (final entry in _connections.entries) {
      final connection = entry.value;
      try {
        // Send ping to check if connection is alive
        final pingMessage = jsonEncode({
          'type': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        // Handle different WebSocket connection types
        if (connection.toString().contains('WebSocketChannel')) {
          // web_socket_channel package uses sink.add()
          connection.sink.add(pingMessage);
        } else {
          // dart:io WebSocket uses add()
          connection.add(pingMessage);
        }
      } catch (e) {
        deadConnections.add(entry.key);
      }
    }
    
    // Remove dead connections
    for (final connectionId in deadConnections) {
      final userId = _userConnections[connectionId]?.toString() ?? '';
      _handleDisconnection(connectionId, userId);
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    
    // Close all connections
    for (final connection in _connections.values) {
      try {
        // Handle different WebSocket connection types
        if (connection.toString().contains('WebSocketChannel')) {
          // web_socket_channel package uses sink.close()
          connection.sink.close();
        } else {
          // dart:io WebSocket uses close()
          connection.close();
        }
      } catch (e) {
        print('Error closing connection: $e');
      }
    }
    
    _connections.clear();
    _userConnections.clear();
  }
}
