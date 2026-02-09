import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../modules/chat/chat_service.dart';

class ConversationRoutes {
  late final Router router;

  ConversationRoutes() {
    print('ConversationRoutes constructor called');
    router = Router()
      ..get('/', _getConversations)
      ..post('/', _createConversation)
      ..get('/<id>/messages', _getConversationMessages)
      ..get('/<id>/messages/', _getConversationMessages)  // Handle trailing slash
      ..post('/<id>/messages', _sendMessage)
      ..post('/<id>/messages/', _sendMessage)  // Handle trailing slash
      ..put('/<id>/read', _markConversationAsRead)
      ..put('/<id>/read/', _markConversationAsRead);  // Handle trailing slash
  }

  Future<Response> _getConversations(Request request) async {
    try {
      final userId = request.url.queryParameters['userId'];
      
      if (userId == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'userId is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Convert string userId to integer for database query
      int userIdInt;
      try {
        userIdInt = int.parse(userId);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid userId format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = DBConnection.getConnection();
      
      // Get conversations for the user
      final result = await conn.execute('''
        SELECT c.id, c.name, c.type, c.created_at, c.updated_at,
               cm.last_read_at,
               (SELECT COUNT(*) FROM messages m 
                WHERE m.conversation_id = c.id 
                AND m.created_at > COALESCE(cm.last_read_at, '1970-01-01')) as unread_count
        FROM conversations c
        JOIN conversation_members cm ON c.id = cm.conversation_id
        WHERE cm.user_id = :userId
        ORDER BY c.updated_at DESC
      ''', {'userId': userIdInt});

      final conversations = result.rows.map((row) {
        return {
          'id': row.colByName('id'),
          'name': row.colByName('name'),
          'type': row.colByName('type'),
          'createdAt': row.colByName('created_at'),
          'updatedAt': row.colByName('updated_at'),
          'lastReadAt': row.colByName('last_read_at'),
          'unreadCount': int.tryParse(row.colByName('unread_count')?.toString() ?? '0') ?? 0,
        };
      }).toList();

      return Response.ok(
        jsonEncode({'success': true, 'data': conversations}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error fetching conversations: $e');
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
      
      if (user1IdStr == null || user2IdStr == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'user1Id and user2Id are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Convert string IDs to integers for database operations
      int user1Id, user2Id;
      try {
        user1Id = int.parse(user1IdStr);
        user2Id = int.parse(user2IdStr);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid user ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = DBConnection.getConnection();
      
      // Check if conversation already exists (both directions: A->B or B->A)
      final existing = await conn.execute('''
        SELECT DISTINCT c.id FROM conversations c
        JOIN conversation_members cm1 ON c.id = cm1.conversation_id
        JOIN conversation_members cm2 ON c.id = cm2.conversation_id
        WHERE c.type = 'direct'
        AND ((cm1.user_id = :user1Id AND cm2.user_id = :user2Id)
        OR (cm1.user_id = :user2Id AND cm2.user_id = :user1Id))
      ''', {'user1Id': user1Id, 'user2Id': user2Id});

      if (existing.rows.isNotEmpty) {
        final conversationId = existing.rows.first.colByName('id');
        return Response.ok(
          jsonEncode({
            'success': true, 
            'message': 'Conversation already exists',
            'data': {'id': conversationId}
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Create new conversation
      await conn.execute('''
        INSERT INTO conversations (type, created_by) 
        VALUES ('direct', :created_by)
      ''', {'created_by': user1Id});
      
      // Get the last inserted ID
      final lastIdResult = await conn.execute('SELECT LAST_INSERT_ID() as id');
      final conversationId = lastIdResult.rows.first.colByName('id');

      // Add members
      await conn.execute('''
        INSERT INTO conversation_members (conversation_id, user_id) 
        VALUES (:conversation_id1, :user_id1), (:conversation_id2, :user_id2)
      ''', {
        'conversation_id1': conversationId, 
        'user_id1': user1Id, 
        'conversation_id2': conversationId, 
        'user_id2': user2Id
      });

      return Response.ok(
        jsonEncode({
          'success': true, 
          'message': 'Conversation created successfully',
          'data': {'id': conversationId}
        }),
        headers: {'Content-Type': 'application/json'},
      );
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
      // Convert string ID to integer for database operations
      int conversationId;
      try {
        conversationId = int.parse(id);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid conversation ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type, 
               m.created_at, m.updated_at, u.username as sender_name
        FROM messages m
        JOIN users u ON m.sender_id = u.id
        WHERE m.conversation_id = :conversation_id
        ORDER BY m.created_at ASC
      ''', {'conversation_id': conversationId});

      final messages = result.rows.map((row) {
        return {
          'id': row.colByName('id'),
          'conversationId': row.colByName('conversation_id'),
          'senderId': row.colByName('sender_id'),
          'senderName': row.colByName('sender_name'),
          'content': row.colByName('content'),
          'type': row.colByName('type'),
          'createdAt': row.colByName('created_at'),
          'updatedAt': row.colByName('updated_at'),
        };
      }).toList();

      return Response.ok(
        jsonEncode({'success': true, 'data': messages}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error fetching messages: $e');
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
      
      final senderIdStr = data['senderId'];
      final content = data['content'];
      
      if (senderIdStr == null || content == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'senderId and content are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Convert string IDs to integers for database operations
      int senderId, conversationId;
      try {
        senderId = int.parse(senderIdStr);
        conversationId = int.parse(id);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        INSERT INTO messages (conversation_id, sender_id, content, type) 
        VALUES (:conversation_id, :sender_id, :content, 'text')
      ''', {
        'conversation_id': conversationId, 
        'sender_id': senderId, 
        'content': content
      });

      // Get the last inserted ID
      final lastIdResult = await conn.execute('SELECT LAST_INSERT_ID() as id');
      final messageId = lastIdResult.rows.first.colByName('id');

      // Update conversation updated_at
      await conn.execute('''
        UPDATE conversations SET updated_at = NOW() WHERE id = :id
      ''', {'id': conversationId});

      return Response.ok(
        jsonEncode({
          'success': true, 
          'message': 'Message sent successfully',
          'data': {'id': messageId}
        }),
        headers: {'Content-Type': 'application/json'},
      );
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
      
      final userIdStr = data['userId'];
      
      if (userIdStr == null) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'userId is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Convert string IDs to integers for database operations
      int userId, conversationId;
      try {
        userId = int.parse(userIdStr);
        conversationId = int.parse(id);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Invalid ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        UPDATE conversation_members 
        SET last_read_at = NOW() 
        WHERE conversation_id = :conversation_id AND user_id = :user_id
      ''', {'conversation_id': conversationId, 'user_id': userId});

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Conversation marked as read'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error marking conversation as read: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}