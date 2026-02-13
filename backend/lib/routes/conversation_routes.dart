import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../modules/chat/chat_service.dart';
import '../modules/chat/websocket_server.dart';
import '../services/auth_service.dart';
import '../database/db_connection.dart';

class ConversationRoutes {
  late final Router router;

  ConversationRoutes() {
    router = Router()
      ..get('/', _getConversations)
      ..get('/users/list', _getAvailableUsers)
      ..post('/', _createConversation)
      ..get('/<id>/messages', _getConversationMessages)
      ..get('/<id>/messages/', _getConversationMessages)
      ..post('/<id>/messages', _sendMessage)
      ..post('/<id>/messages/', _sendMessage)
      ..put('/<id>/read', _markConversationAsRead)
      ..put('/<id>/read/', _markConversationAsRead)
      ..post('/messages/read', _markMessagesAsRead)
      ..post('/typing', _setTypingIndicator)
      ..get('/<id>/typing', _getTypingUsers);
  }

  Future<Response> _getConversations(Request request) async {
    try {
      final userId = request.url.queryParameters['userId'];
      final before = request.url.queryParameters['before'];
      final limit = request.url.queryParameters['limit'];
      
      if (userId == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'userId is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      int userIdInt;
      try {
        userIdInt = int.parse(userId);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid userId format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      int? limitInt;
      if (limit != null) {
        try {
          limitInt = int.parse(limit);
        } catch (e) {
          // Use default limit if invalid
        }
      }

      final result = await ChatService.getConversations(
        userId: userIdInt,
        before: before,
        limit: limitInt,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Error fetching conversations: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getAvailableUsers(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      
      // Get all users except the current user (if userId is provided in query)
      final currentUserId = request.url.queryParameters['excludeUserId'];
      
      String query = '''
        SELECT u.id, u.username, 
               COALESCE(e.prenom, '') as first_name,
               COALESCE(e.nom, '') as last_name,
               COALESCE(e.email, u.username) as email
        FROM users u
        LEFT JOIN employees e ON u.id = e.user_id
      ''';
      
      final params = <String, dynamic>{};
      
      if (currentUserId != null) {
        query += ' WHERE u.id != :currentUserId';
        params['currentUserId'] = currentUserId;
      }
      
      query += ' ORDER BY u.username ASC';
      
      final result = await conn.execute(query, params);
      
      final users = result.rows.map((row) => {
        'id': row.colByName('id'),
        'username': row.colByName('username'),
        'firstName': row.colByName('first_name'),
        'lastName': row.colByName('last_name'),
        'email': row.colByName('email'),
      }).toList();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': users,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error fetching available users: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }


  Future<Response> _createConversation(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final user1IdStr = data['user1Id'];
      final user2IdStr = data['user2Id'];
      final name = data['name']; // For group conversations
      final type = data['type'] ?? 'direct';
      
      if (user1IdStr == null || user2IdStr == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'user1Id and user2Id are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      int user1Id, user2Id;
      try {
        user1Id = user1IdStr is int ? user1IdStr : int.parse(user1IdStr.toString());
        user2Id = user2IdStr is int ? user2IdStr : int.parse(user2IdStr.toString());
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid user ID format: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await ChatService.createConversation(
        user1Id: user1Id,
        user2Id: user2Id,
        type: type,
        name: name,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Error creating conversation: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getConversationMessages(Request request, String id) async {
    try {
      final before = request.url.queryParameters['before'];
      final limit = request.url.queryParameters['limit'];
      
      int? limitInt;
      if (limit != null) {
        try {
          limitInt = int.parse(limit);
        } catch (e) {
          // Use default limit if invalid
        }
      }

      final result = await ChatService.getMessages(
        conversationId: id,
        before: before,
        limit: limitInt,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Error fetching conversation messages: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _sendMessage(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final content = data['content'];
      final incomingType = data['type'] ?? 'text';
      // Sanitize type to match DB enum: ('text','file','voice','system')
      String type;
      try {
        final t = incomingType.toString().toLowerCase();
        if (['text', 'file', 'voice', 'system'].contains(t)) {
          type = t;
        } else if (t == 'image' || t == 'mixed') {
          type = 'file';
        } else if (t == 'audio') {
          type = 'voice';
        } else {
          // Default based on presence of uploads
          final maybeUploads = data['upload_ids'] as List?;
          type = (maybeUploads != null && maybeUploads.isNotEmpty) ? 'file' : 'text';
        }
      } catch (e) {
        type = 'text';
      }

      // Log incoming message payload for debugging
      print('[REST] Incoming sendMessage payload: ${jsonEncode(data)} => sanitized type="$type"');
      final replyToId = data['replyToId'];
      final clientMessageId = data['clientMessageId'];
      final uploadIds = data['upload_ids'] as List<dynamic>?;
      
      // Extract voice metadata if present (for voice type messages or audio file uploads)
      Map<String, dynamic>? voiceMetadata;
      if (type == 'voice' || type == 'file') {
        final durationSeconds = data['duration_seconds'];
        final waveformData = data['waveform_data'];
        
        // Also check upload IDs for audio mime types
        if (durationSeconds != null || (uploadIds != null && uploadIds.isNotEmpty)) {
          // Query the database to check if uploads are audio
          bool hasAudioUpload = false;
          if (uploadIds != null && uploadIds.isNotEmpty) {
            try {
              final conn = DBConnection.getConnection();
              for (final uploadId in uploadIds) {
                final result = await conn.execute(
                  'SELECT mime_type FROM file_uploads WHERE id = :id',
                  {'id': uploadId.toString()}
                );
                if (result.rows.isNotEmpty) {
                  final mimeType = result.rows.first.colByName('mime_type') as String?;
                  if (mimeType != null && (mimeType.startsWith('audio/') || mimeType == 'audio/aac' || mimeType == 'audio/m4a')) {
                    hasAudioUpload = true;
                    break;
                  }
                }
              }
            } catch (e) {
              print('[REST] Warning: Could not check mime types: $e');
            }
          }
          
          if (durationSeconds != null || hasAudioUpload) {
            voiceMetadata = {
              'duration_seconds': durationSeconds is String ? double.tryParse(durationSeconds) : durationSeconds,
              if (waveformData != null) 'waveform_data': waveformData,
            };
            print('[REST] Extracted voice metadata: $voiceMetadata');
          }
        }
      }

      // Enforce server-side identity: require Authorization header and extract userId
      final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(jsonEncode({'success': false, 'message': 'Authorization required'}), headers: {'Content-Type': 'application/json'});
      }

      final token = authHeader.split(' ').last;
      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.forbidden(jsonEncode({'success': false, 'message': 'Invalid token'}), headers: {'Content-Type': 'application/json'});
      }

      final senderId = payload['userId'];
      
      if (content == null || senderId == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'content and senderId are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      int senderIdInt;
      try {
        senderIdInt = int.parse(senderId.toString());
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid senderId format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await ChatService.sendMessage(
        conversationId: id,
        senderId: senderIdInt,
        content: content,
        type: type,
        replyToId: replyToId,
        clientMessageId: clientMessageId,
        uploadIds: uploadIds?.map((id) => id.toString()).toList(),
        voiceMetadata: voiceMetadata,
      );

      if (result['success']) {
        // Broadcast to all participants in conversation via WebSocket (including sender)
        // The sender's optimistic message will be deduplicated by clientMessageId
        final messageId = result['message']?['id'] ?? 'unknown';
        print('[REST-SEND] Message sent: id=$messageId conversationId=$id senderId=$senderIdInt');
        print('[REST-SEND] Broadcasting via WebSocket to conversation members...');
        
        try {
          print('[REST-SEND] About to call broadcastToConversationMembers...');
          print('[REST-SEND] excludeUserId parameter: not provided (should be null)');
          await WebSocketServer.broadcastToConversationMembers(
            id,
            {
              'type': 'message:created',
              'payload': {'message': result['message']},
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          );
          print('[REST-SEND] Broadcast complete for messageId=$messageId');
        } catch (e) {
          print('[REST-SEND-ERROR] Broadcast failed: $e');
          print('[REST-SEND-ERROR] Stack trace: ${StackTrace.current}');
        }
        
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _markConversationAsRead(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final userId = data['userId'];
      final messageId = data['messageId'];
      
      if (userId == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'userId is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      int userIdInt;
      try {
        userIdInt = int.parse(userId);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid userId format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await ChatService.markConversationAsRead(
        conversationId: id,
        userId: userIdInt,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Error marking conversation as read: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _markMessagesAsRead(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final messageIds = (data['messageIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final userId = data['userId'];
      
      if (messageIds.isEmpty || userId == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'messageIds and userId are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      int userIdInt;
      try {
        userIdInt = int.parse(userId);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid userId format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await ChatService.markMessagesAsRead(
        messageIds: messageIds,
        userId: userIdInt,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Error marking messages as read: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _setTypingIndicator(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final conversationId = data['conversationId'];
      final userId = data['userId'];
      final isTyping = data['isTyping'];
      
      if (conversationId == null || userId == null || isTyping == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'conversationId, userId, and isTyping are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      int userIdInt;
      try {
        userIdInt = int.parse(userId);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid userId format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await ChatService.setTypingIndicator(
        conversationId: conversationId,
        userId: userIdInt,
        isTyping: isTyping,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Error setting typing indicator: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getTypingUsers(Request request, String id) async {
    try {
      final result = await ChatService.getTypingUsers(id);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Error getting typing users: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
