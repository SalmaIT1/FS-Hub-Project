import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/chat_service.dart';
import '../../../../shared/database/connection.dart';
import '../../../../core/middleware/auth_middleware.dart';

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
      ..post('/<id>/read', _markConversationAsRead)
      ..post('/<id>/read/', _markConversationAsRead)
      ..post('/messages/read', _markMessagesAsRead)
      ..post('/typing', _setTypingIndicator)
      ..get('/<id>/typing', _getTypingUsers)
      ..delete('/<id>/leave', _leaveConversation);
  }

  // ── GET / ─────────────────────────────────────────────────────────────────
  Future<Response> _getConversations(Request request) async {
    try {
      // Always use authenticated caller's ID — ignore any userId query param
      // to prevent users from fetching other people's conversation lists.
      final userId = request.authUserId;
      final before = request.url.queryParameters['before'];
      final limitStr = request.url.queryParameters['limit'];
      final limit = int.tryParse(limitStr ?? '') ?? 50;

      final result = await ChatService.getConversations(
        userId: userId,
        before: before,
        limit: limit,
      );

      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('Error fetching conversations: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── GET /users/list ───────────────────────────────────────────────────────
  Future<Response> _getAvailableUsers(Request request) async {
    try {
      final currentUserId = request.authUserId;
      final conn = DBConnection.getConnection();

      final result = await conn.execute(
        '''SELECT u.id, u.username,
                  COALESCE(e.prenom, '') as first_name,
                  COALESCE(e.nom, '') as last_name,
                  COALESCE(e.email, u.username) as email
           FROM users u
           LEFT JOIN employees e ON u.id = e.user_id
           WHERE u.id != :currentUserId
           ORDER BY u.username ASC''',
        {'currentUserId': currentUserId},
      );

      final users = result.rows
          .map((row) => {
                'id': row.colByName('id'),
                'username': row.colByName('username'),
                'firstName': row.colByName('first_name'),
                'lastName': row.colByName('last_name'),
                'email': row.colByName('email'),
              })
          .toList();

      return Response.ok(
        jsonEncode({'success': true, 'data': users}),
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

  // ── POST / ────────────────────────────────────────────────────────────────
  Future<Response> _createConversation(Request request) async {
    try {
      final creatorId = request.authUserId;
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final type = data['type']?.toString() ?? 'direct';
      final name = data['name']?.toString();
      final avatarUrl = data['avatarUrl']?.toString();

      final List<String> participantIds = [];
      if (data['participantIds'] is List) {
        participantIds
            .addAll((data['participantIds'] as List).map<String>((e) => e.toString()));
      } else if (data['user2Id'] != null) {
        participantIds.add(data['user2Id'].toString());
      }

      if (participantIds.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'At least one participant is required'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await ChatService.createConversation(
        creatorId: creatorId,
        participantIds: participantIds,
        type: type,
        name: name,
        avatarUrl: avatarUrl,
      );

      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('Error creating conversation: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── GET /<id>/messages ────────────────────────────────────────────────────
  Future<Response> _getConversationMessages(
      Request request, String id) async {
    try {
      final before = request.url.queryParameters['before'];
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 50;

      final result = await ChatService.getMessages(
        conversationId: id,
        userId: request.authUserId,
        before: before,
        limit: limit,
      );

      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── POST /<id>/messages ───────────────────────────────────────────────────
  Future<Response> _sendMessage(Request request, String id) async {
    try {
      // Identity comes from JWT — not from client body.
      final senderId = request.authUserId;
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final content = data['content']?.toString();
      if (content == null || content.isEmpty) {
        return Response(
          400,
          body: jsonEncode(
              {'success': false, 'message': 'content is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final incomingType = data['type']?.toString().toLowerCase() ?? 'text';
      String type;
      if (['text', 'file', 'voice', 'system'].contains(incomingType)) {
        type = incomingType;
      } else if (incomingType == 'image' || incomingType == 'mixed') {
        type = 'file';
      } else if (incomingType == 'audio') {
        type = 'voice';
      } else {
        final maybeUploads = data['upload_ids'] as List?;
        type = (maybeUploads != null && maybeUploads.isNotEmpty) ? 'file' : 'text';
      }

      final replyToId = data['replyToId']?.toString();
      final clientMessageId = data['clientMessageId']?.toString();
      final List<String>? uploadIds =
          (data['upload_ids'] as List?)?.map<String>((e) => e.toString()).toList();

      Map<String, dynamic>? voiceMetadata;
      if ((type == 'voice' || type == 'file') && uploadIds != null && uploadIds.isNotEmpty) {
        final durationSeconds = data['duration_seconds'];
        final waveformData = data['waveform_data'];
        if (durationSeconds != null) {
          voiceMetadata = {
            'duration_seconds': durationSeconds is String
                ? double.tryParse(durationSeconds)
                : durationSeconds,
            if (waveformData != null) 'waveform_data': waveformData,
          };
        }
      }

      final result = await ChatService.sendMessage(
        conversationId: id,
        senderId: senderId,
        content: content,
        type: type,
        replyToId: replyToId,
        clientMessageId: clientMessageId,
        uploadIds: uploadIds,
        voiceMetadata: voiceMetadata,
      );

      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('Error sending message: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── PUT /<id>/read ────────────────────────────────────────────────────────
  Future<Response> _markConversationAsRead(Request request, String id) async {
    try {
      // Use authenticated identity, not body userId.
      final userId = request.authUserId;

      final result = await ChatService.markConversationAsRead(
        conversationId: id,
        userId: userId,
      );

      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── POST /messages/read ───────────────────────────────────────────────────
  Future<Response> _markMessagesAsRead(Request request) async {
    try {
      final userId = request.authUserId;
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final List<String> messageIds =
          (data['messageIds'] as List?)?.map<String>((e) => e.toString()).toList() ?? [];

      if (messageIds.isEmpty) {
        return Response(
          400,
          body: jsonEncode(
              {'success': false, 'message': 'messageIds is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await ChatService.markMessagesAsRead(
        messageIds: messageIds,
        userId: userId,
      );

      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── POST /typing ──────────────────────────────────────────────────────────
  Future<Response> _setTypingIndicator(Request request) async {
    try {
      final userId = request.authUserId;
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conversationId = data['conversationId']?.toString();
      final isTyping = data['isTyping'] == true;

      if (conversationId == null || conversationId.isEmpty) {
        return Response(
          400,
          body: jsonEncode(
              {'success': false, 'message': 'conversationId is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await ChatService.setTypingIndicator(
        conversationId: conversationId,
        userId: userId,
        isTyping: isTyping,
      );

      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── GET /<id>/typing ──────────────────────────────────────────────────────
  Future<Response> _getTypingUsers(Request request, String id) async {
    try {
      final result = await ChatService.getTypingUsers(id);
      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── DELETE /<id>/leave ────────────────────────────────────────────────────
  Future<Response> _leaveConversation(Request request, String id) async {
    try {
      // Use authenticated identity — never trust body userId.
      final userId = request.authUserId;

      final result = await ChatService.leaveConversation(
        conversationId: id,
        userId: userId,
      );

      return result['success'] == true
          ? Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'})
          : Response.internalServerError(
              body: jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('Error leaving conversation: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
