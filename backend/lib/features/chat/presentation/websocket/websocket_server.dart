import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/database/connection.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../domain/services/chat_service.dart';

const _uuid = Uuid();

class WebSocketServer {
  static WebSocketServer? _instance;

  // Store connections as dynamic to support both `dart:io.WebSocket`
  // and `package:web_socket_channel`'s WebSocketChannel used by some clients.
  final Map<String, dynamic> _connections = {};
  final Map<String, String> _userConnections = {}; // connectionId -> userId
  final Map<String, Set<String>> _userToConnections = {}; // userId -> set of connectionIds
  final Map<String, Set<String>> _conversationRooms = {}; // conversationId -> set of connectionIds
  Timer? _cleanupTimer;

  WebSocketServer() {
    _instance = this;
  }

  /// Get the singleton instance for broadcasting
  static WebSocketServer? get instance => _instance;

  Router get router {
    return Router()
      // WebSocket endpoint: requires a short-lived one-time ticket obtained from
      // POST /v1/auth/ws-ticket. Never put long-lived JWTs in the URL.
      ..get('/', _rootHandler)
      ..get('/chat', _chatHandler);
  }

  FutureOr<Response> _rootHandler(Request request) {
    // Backward compatible endpoint: accepts JWT token as query param.
    // (Used by existing web clients: /ws?token=...)
    final token = request.url.queryParameters['token'];
    if (token == null || token.isEmpty) {
      // If token is absent, fall back to the newer ticket-based handler.
      return _chatHandler(request);
    }

    final payload = AuthService.verifyToken(token);
    if (payload == null) {
      return Future.value(Response(
        401,
        body: jsonEncode({'error': 'Unauthorized', 'message': 'Invalid or expired token'}),
        headers: {'Content-Type': 'application/json'},
      ));
    }

    final userId = payload['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      return Future.value(Response(
        401,
        body: jsonEncode({'error': 'Unauthorized', 'message': 'Invalid token payload'}),
        headers: {'Content-Type': 'application/json'},
      ));
    }

    final handler = webSocketHandler((dynamic webSocket) {
      _registerConnection(webSocket, userId);
    });
    return handler(request);
  }

  FutureOr<Response> _chatHandler(Request request) {
    // Accept ticket from query parameter (short-lived, one-time use).
    final ticket = request.url.queryParameters['ticket'];
    if (ticket == null || ticket.isEmpty) {
      return Future.value(Response(
        401,
        body: jsonEncode({'error': 'Unauthorized', 'message': 'WS ticket required'}),
        headers: {'Content-Type': 'application/json'},
      ));
    }

    // Consume and validate the one-time ticket.
    final identity = AuthService.consumeWsTicket(ticket);
    if (identity == null) {
      return Future.value(Response(
        403,
        body: jsonEncode({'error': 'Forbidden', 'message': 'Invalid or expired ticket'}),
        headers: {'Content-Type': 'application/json'},
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

  void _handleMessage(String connectionId, String userId, dynamic message) {
    try {
      final data = jsonDecode(message as String);
      
      switch (data['type']) {
        case 'ping':
          _handlePing(connectionId, userId);
          break;
        
        case 'join':
        case 'join_conversation':
          _handleJoinConversation(connectionId, userId, data['data'] ?? {});
          break;
          
        case 'message':
            _handleChatMessage(connectionId, userId, data['data']);
          break;
          
        case 'typing':
          _handleTyping(connectionId, userId, data['data']);
          break;
          
        case 'presence':
          _handlePresence(connectionId, userId, data['data']);
          break;
          
        case 'file_upload_start':
          _handleFileUpload(connectionId, userId, data['data']);
          break;
          
        default:
          print('[WS-MESSAGE] Unknown message type: ${data['type']}');
      }
    } catch (e) {
      print('[WS-MESSAGE-ERROR] Error handling WebSocket message: $e');
      _sendError(connectionId, 'Failed to process message: $e');
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
      );

      if (result['success']) {
        final message = result['message'];
        
        // Confirmation is still needed for the sender if they didn't get it via broadcast
        // (though in current logic, broadcast excludes sender, so we MUST send this)
        _sendToConnection(connectionId, {
          'type': 'message:created',
          'payload': {'message': message},
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        _sendError(connectionId, result['message']);
      }
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
          excludeUserId: userId,
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
      final membersRes = await conn.execute('''
        SELECT DISTINCT cm2.user_id 
        FROM conversation_members cm1
        JOIN conversation_members cm2 ON cm1.conversation_id = cm2.conversation_id
        WHERE cm1.user_id = :userId 
        AND cm2.user_id != :userId 
        AND cm1.left_at IS NULL
        AND cm2.left_at IS NULL
      ''', {'userId': userId});

      final event = {
        'type': 'presence',
        'payload': {
          'userId': userId,
          'state': state,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // 3. Broadcast to all mutual members who are currently online
      int reached = 0;
      for (final row in membersRes.rows) {
        final otherUserId = row.colByName('user_id')?.toString();
        if (otherUserId != null) {
          final connections = _userToConnections[otherUserId];
          if (connections != null) {
            for (final connId in connections) {
              _sendToConnection(connId, event);
              reached++;
            }
          }
        }
      }
      
      print('[WS-PRESENCE] userId=$userId is $state. Broadcast to $reached connections.');
    } catch (e) {
      print('[WS-PRESENCE-ERROR] Failed to update presence for $userId: $e');
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
    String? excludeUserId,
  }) async {
    try {
      final conn = DBConnection.getConnection();
      
      // 1. Find all members of this conversation
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

      int sentCount = 0;
      for (final row in membersRes.rows) {
        final memberId = row.colByName('user_id')?.toString();
        if (memberId == null || memberId == excludeUserId) continue;

        final connections = _userToConnections[memberId];
        if (connections != null) {
          for (final connId in connections) {
            _sendToConnection(connId, message);
            sentCount++;
          }
        }
      }
      print('[WS-BROADCAST] Sent ${message['type']} to $sentCount connections in conversation $conversationId');
    } catch (e) {
      print('[WS-BROADCAST-ERROR] Error broadcasting to conversation: $e');
    }
  }

  void _sendToConnection(String connectionId, Map<String, dynamic> message) {
    final connection = _connections[connectionId];
    if (connection != null) {
      try {
        final jsonMessage = jsonEncode(message);
        
        // Handle different WebSocket connection types
        if (connection.toString().contains('WebSocketChannel')) {
          // web_socket_channel package uses sink.add()
          connection.sink.add(jsonMessage);
        } else {
          // dart:io WebSocket uses add()
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
    
    // Remove from all conversation rooms and prune empty sets to prevent memory leak.
    final emptyRooms = <String>[];
    for (final entry in _conversationRooms.entries) {
      entry.value.remove(connectionId);
      if (entry.value.isEmpty) emptyRooms.add(entry.key);
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

  void _handleJoinConversation(String connectionId, String userId, Map<String, dynamic> data) {
    try {
      final conversationId = data['conversationId']?.toString();
      if (conversationId == null || conversationId.isEmpty) {
        print('[WS-ROOM] ERROR: No conversationId provided');
        _sendError(connectionId, 'conversationId is required');
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
  }) async {
    print('[WS-BROADCAST-STATIC] broadcastToConversationMembers called for conv=$conversationId');
    final instance = _instance;
    if (instance == null) {
      print('[WS-BROADCAST-STATIC] ERROR: WebSocketServer instance is null!');
      return;
    }
    
    try {
      print('[WS-BROADCAST-STATIC] Calling instance._broadcastToConversation...');
      await instance._broadcastToConversation(
        conversationId,
        message,
        excludeUserId: excludeUserId,
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
