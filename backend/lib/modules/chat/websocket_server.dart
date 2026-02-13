import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../database/db_connection.dart';
import '../../services/auth_service.dart';
import 'chat_service.dart';

class WebSocketServer {
  static WebSocketServer? _instance;

  // Store connections as dynamic to support both `dart:io.WebSocket`
  // and `package:web_socket_channel`'s WebSocketChannel used by some clients.
  final Map<String, dynamic> _connections = {};
  final Map<String, int> _userConnections = {}; // connectionId -> userId
  final Map<String, Set<String>> _userToConnections = {}; // userId -> set of connectionIds
  final Map<String, Set<String>> _conversationRooms = {}; // conversationId -> set of connectionIds
  Timer? _cleanupTimer;

  WebSocketServer() {
    _instance = this;
  }

  /// Get the singleton instance for broadcasting
  static WebSocketServer? get instance => _instance;

  /// Extract JWT token from request URL query params or path
  String? _extractToken(Request request) {
    // Try query parameter first
    final queryToken = request.url.queryParameters['token'];
    if (queryToken != null && queryToken.isNotEmpty) {
      print('[WS-TOKEN-EXTRACT] Found token in query param');
      return queryToken;
    }
    
    // Try Authorization Bearer header
    final authHeader = request.headers['authorization'];
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      final token = authHeader.substring(7);
      if (token.isNotEmpty) {
        print('[WS-TOKEN-EXTRACT] Found token in Authorization header');
        return token;
      }
    }
    
    print('[WS-TOKEN-EXTRACT] NO TOKEN FOUND in query or headers');
    return null;
  }

  Router get router {
    return Router()
      // WebSocket endpoint supporting multiple token sources
      ..get('/chat', _chatHandler)
      ..get('/chat/<token>', (Request request, String token) {
        print('[WS-ROUTE] Token in path param: ${token.isNotEmpty ? "present" : "EMPTY"}');
        return _processWebSocket(request, token);
      });
  }

  Future<Response> _chatHandler(Request request) {
    // Extract token from query or headers
    final token = _extractToken(request);
    if (token == null || token.isEmpty) {
      print('[WS-AUTH] Token missing - rejecting connection');
      return Future.value(Response(
        401,
        body: jsonEncode({'error': 'Unauthorized', 'message': 'Token required'}),
        headers: {'Content-Type': 'application/json'},
      ));
    }
    return _processWebSocket(request, token);
  }

  Future<Response> _processWebSocket(Request request, String token) async {
    print('[WS-PROCESS] Authenticating with token: ${token.isNotEmpty ? "present (${token.length} chars)" : "EMPTY"}');

    final payload = AuthService.verifyToken(token);
    if (payload == null) {
      print('[WS-AUTH] Token verification FAILED');
      return Response(
        403,
        body: jsonEncode({'error': 'Unauthorized', 'message': 'Invalid token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final userId = payload['userId']?.toString() ?? '';
    if (userId.isEmpty) {
      print('[WS-AUTH] Token has no userId');
      return Response(
        403,
        body: jsonEncode({'error': 'Invalid token payload'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    print('[WS-AUTH] Token valid for userId=$userId');

    // Use webSocketHandler to upgrade the connection
    final handler = webSocketHandler((dynamic webSocket) {
      _registerConnection(webSocket, userId);
    });

    return handler(request);
  }

  void _registerConnection(dynamic webSocket, String userId) {
    final connectionId = _generateConnectionId();
    final userIdInt = int.tryParse(userId) ?? 0;

    print('[WS-REGISTER] Registering userId=$userId connectionId=$connectionId');

    // Store connection
    _connections[connectionId] = webSocket;
    _userConnections[connectionId] = userIdInt;
    _userToConnections.putIfAbsent(userId, () => {}).add(connectionId);

    print('[WS-REGISTER] Active connections now: ${_userConnections.values.toSet()}');

    // Send welcome message
    _sendToConnection(connectionId, {
      'type': 'connected',
      'data': {'userId': userId, 'connectionId': connectionId},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

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
        senderId: int.parse(userId),
        content: messageData['content'],
        type: messageData['type'],
        replyToId: messageData['replyToId'],
        clientMessageId: messageData['clientMessageId'],
      );

      if (result['success']) {
        final message = result['message'];
        
        // Broadcast to all participants in conversation
        await _broadcastToConversation(
          messageData['conversationId'],
          {
            'type': 'message:created',
            'payload': {'message': message},
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          excludeUserId: userId,
        );
        
        // Send confirmation to sender
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
        userId: int.parse(userId),
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

  void _handlePresence(String connectionId, String userId, Map<String, dynamic> presenceData) {
    // Handle presence updates (online/away/busy)
    // This would update user presence in database and broadcast to connections
  }

  void _handleFileUpload(String connectionId, String userId, Map<String, dynamic> uploadData) {
    // Handle file upload initiation
    // This would generate signed URLs or handle multipart upload
  }

  Future<void> _broadcastToConversation(
    String conversationId,
    Map<String, dynamic> message, {
    String? excludeUserId,
  }) async {
    try {
      final roomKey = 'conv_$conversationId';
      final roomConnections = _conversationRooms[roomKey] ?? {};

      print('[WS-BROADCAST] Starting broadcast for conversation=$conversationId');
      print('[WS-BROADCAST] Message type=${message['type']} messageId=${message['payload']?['message']?['id']}');
      print('[WS-BROADCAST] Subscribers in room=$roomKey: ${roomConnections.length}');
      print('[WS-BROADCAST] Connection mapping: ${_userConnections.entries.map((e) => "${e.key}→userId${e.value}").join(", ")}');

      int sentCount = 0;
      for (final connectionId in roomConnections) {
        final userId = _userConnections[connectionId]?.toString() ?? '?';
        
        // Skip excluded user
        if (excludeUserId != null && userId == excludeUserId.toString()) {
          print('[WS-BROADCAST] Skipping sender (userId=$userId, excludeUserId=$excludeUserId)');
          continue;
        }
        
        if (_connections.containsKey(connectionId)) {
          print('[WS-BROADCAST] Delivering to userId=$userId via connectionId=$connectionId');
          _sendToConnection(connectionId, message);
          sentCount++;
        } else {
          print('[WS-BROADCAST] WARNING: Room has connectionId=$connectionId but connection not active');
        }
      }
      print('[WS-BROADCAST] Broadcast complete: sent to $sentCount subscribers');
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

  void _handleError(String connectionId, String userId, dynamic error) {
    print('[WS-ERROR] WebSocket error for connection $connectionId (user $userId): $error');
    _handleDisconnection(connectionId, userId);
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
    
    // Remove from all conversation rooms
    for (final roomConnections in _conversationRooms.values) {
      roomConnections.remove(connectionId);
    }
    
    print('[WS-DISCONNECT] Cleanup complete. Remaining users: ${_userConnections.values.toSet()}');
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

  String _generateConnectionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_connections.length}';
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
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
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
