import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/chat_entities.dart';
import '../domain/message_state_machine.dart';

/// REST client for chat API
/// 
/// Binds to /v1 backend contract:
/// - GET /v1/conversations → list
/// - GET /v1/conversations/{id} → detail
/// - GET /v1/conversations/{id}/messages → messages
/// - POST /v1/conversations/{id}/messages → create
/// - POST /v1/auth/login → auth
/// - POST /v1/auth/refresh → token refresh
/// - POST /v1/uploads/signed-url → request upload slot
/// - POST /v1/uploads/complete → mark upload done
class ChatRestClient {
  final String baseUrl;
  final Future<String> Function() tokenProvider;
  final http.Client httpClient;

  ChatRestClient({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// GET /v1/conversations
  /// Requires userId (extract from JWT or pass explicitly)
  Future<List<ConversationEntity>> getConversations({
    required String userId,
    int limit = 50,
    String? before,
  }) async {
    try {
      final token = await tokenProvider();
      var url = '$baseUrl/v1/conversations?userId=$userId&limit=$limit';
      if (before != null) url += '&before=$before';

      final response = await httpClient.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final conversations = (data['conversations'] as List?)
            ?.map((c) => ConversationEntity.fromServerJson(c))
            .toList() ?? [];
        return conversations;
      } else {
        throw Exception('Failed to fetch conversations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching conversations: $e');
    }
  }

  /// GET /v1/conversations/{conversationId}
  Future<ConversationEntity> getConversation(String conversationId) async {
    try {
      final token = await tokenProvider();
      final response = await httpClient.get(
        Uri.parse('$baseUrl/v1/conversations/$conversationId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ConversationEntity.fromServerJson(data['conversation'] ?? data);
      } else {
        throw Exception('Failed to fetch conversation: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching conversation: $e');
    }
  }

  /// GET /v1/conversations/{conversationId}/messages
  /// 
  /// Fetches message history with pagination
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    int limit = 50,
    String? before,
  }) async {
    try {
      final token = await tokenProvider();
      var url = '$baseUrl/v1/conversations/$conversationId/messages?limit=$limit';
      if (before != null) url += '&before=$before';

      final response = await httpClient.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = (data['messages'] as List?)
            ?.map((m) => ChatMessage.fromServerJson(m))
            .toList() ?? [];
        return messages;
      } else {
        throw Exception('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }

  /// POST /v1/conversations/{conversationId}/messages
  /// 
  /// Send message (text or with attachments)
  /// 
  /// Backend response includes server-assigned ID and canonical timestamp
  /// 
  /// Request body:
  /// {
  ///   senderId: string,
  ///   content: string,
  ///   type: 'text'|'file'|'image'|'audio',
  ///   replyToId?: string,
  ///   clientMessageId?: string  (for idempotency),
  ///   meta?: {attachments: [...]}
  /// }
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required String type,
    String? replyToId,
    String? clientMessageId,
    Map<String, dynamic>? meta,
  }) async {
    try {
      print('[REST] Sending message: conversationId=$conversationId clientMsgId=$clientMessageId');
      final token = await tokenProvider();
      final body = {
        'senderId': senderId,
        'content': content,
        'type': type,
        if (replyToId != null) 'replyToId': replyToId,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        if (meta != null) 'meta': meta,
      };

      print('[REST] POST /v1/conversations/$conversationId/messages body=${jsonEncode(body)}');
      final response = await httpClient.post(
        Uri.parse('$baseUrl/v1/conversations/$conversationId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('[REST] Response status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final msg = ChatMessage.fromServerJson(data['message'] ?? data);
        print('[REST] Message created: serverId=${msg.id} clientMsgId=$clientMessageId');
        return msg;
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('[REST-ERROR] Error sending message: $e');
      throw Exception('Error sending message: $e');
    }
  }

  /// Authentication: POST /v1/auth/login
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error logging in: $e');
    }
  }

  /// Token refresh: POST /v1/auth/refresh
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/v1/auth/refresh'),
        headers: {
          'Authorization': 'Bearer $refreshToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error refreshing token: $e');
    }
  }

  /// GET /v1/conversations/users/list
  /// Get list of available users to start conversations with
  Future<List<Map<String, dynamic>>> getAvailableUsers({String? excludeUserId}) async {
    try {
      final token = await tokenProvider();
      var url = '$baseUrl/v1/conversations/users/list';
      if (excludeUserId != null) url += '?excludeUserId=$excludeUserId';

      final response = await httpClient.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to fetch users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching available users: $e');
    }
  }

  /// POST /v1/conversations
  /// Create a new conversation
  Future<Map<String, dynamic>> createConversation({
    required int user1Id,
    required int user2Id,
    String type = 'direct',
    String? name,
  }) async {
    try {
      final token = await tokenProvider();

      final response = await httpClient.post(
        Uri.parse('$baseUrl/v1/conversations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user1Id': user1Id,
          'user2Id': user2Id,
          'type': type,
          'name': name,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create conversation: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating conversation: $e');
    }
  }

  /// PUT /v1/conversations/{conversationId}/read
  /// Mark all messages in conversation as read for current user
  Future<Map<String, dynamic>> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final token = await tokenProvider();
      
      final response = await httpClient.put(
        Uri.parse('$baseUrl/v1/conversations/$conversationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to mark conversation as read: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking conversation as read: $e');
    }
  }
}
