import 'dart:async';
import 'dart:convert';
import 'dart:convert' show base64Url, utf8;
import 'package:http/http.dart' as http;
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';
import 'package:fs_hub/shared/models/chat_models.dart';

class ChatRemoteDatasource {
  final String baseUrl;
  final Future<String> Function() tokenProvider;

  ChatRemoteDatasource({required this.baseUrl, required this.tokenProvider});

  Future<Map<String, String>> _getHeaders() async => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${await tokenProvider()}',
  };

  Future<List<ConversationEntity>> getConversations() async {
    final token = await tokenProvider();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> conversations = data['conversations'] ?? [];
      return conversations.map((c) => ConversationEntity.fromJson(c)).toList();
    }
    throw Exception('Failed to load conversations: ${response.statusCode}');
  }

  Future<List<ChatMessage>> getMessages({required String conversationId, int? limit, String? before}) async {
    final token = await tokenProvider();
    var url = '$baseUrl/v1/conversations/$conversationId/messages';
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (before != null) params['before'] = before;
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> messages = data['messages'] ?? [];
      return messages.map((m) {
        final msg = Map<String, dynamic>.from(m);
        msg['isFromMe'] = msg['isFromMe'] ?? false;
        return ChatMessage.fromJson(msg);
      }).toList();
    }
    throw Exception('Failed to load messages: ${response.statusCode}');
  }

  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final token = await tokenProvider();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/conversations/$conversationId/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'content': content,
        'type': 'text',
        'senderId': senderId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return ChatMessage.fromJson(data['message'] ?? data);
    }
    throw Exception('Failed to send message: ${response.statusCode}');
  }

  Future<ChatMessage> sendMessageWithAttachments({
    required String conversationId,
    required String senderId,
    required String content,
    String type = 'text',
    required List<String> uploadIds,
    Map<String, dynamic>? voiceMetadata,
  }) async {
    final token = await tokenProvider();
    final body = <String, dynamic>{
      'content': content,
      'type': type,
      'senderId': senderId,
      'uploadIds': uploadIds,
    };
    if (voiceMetadata != null) {
      body['voiceMetadata'] = voiceMetadata;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/v1/conversations/$conversationId/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return ChatMessage.fromJson(data['message'] ?? data);
    }
    throw Exception('Failed to send message: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> requestSignedUrl({
    required String contentType,
    required String filename,
    required int fileSize,
  }) async {
    final token = await tokenProvider();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/uploads/signed-url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'contentType': contentType,
        'filename': filename,
        'fileSize': fileSize,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get signed URL: ${response.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getAvailableUsers() async {
    final token = await tokenProvider();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/conversations/users/list'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    throw Exception('Failed to load users: ${response.statusCode}');
  }

  Future<ConversationEntity> createConversation({required String user2Id}) async {
    final token = await tokenProvider();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'user2Id': user2Id}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return ConversationEntity.fromJson(data['conversation'] ?? data);
    }
    throw Exception('Failed to create conversation: ${response.statusCode}');
  }

  Future<ConversationEntity> createGroupConversation({
    required List<String> participantIds,
    required String name,
    String type = 'group',
  }) async {
    final token = await tokenProvider();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'participantIds': participantIds,
        'name': name,
        'type': type,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return ConversationEntity.fromJson(data['conversation'] ?? data);
    }
    throw Exception('Failed to create group conversation: ${response.statusCode}');
  }

  Future<String?> getCurrentUserId() async {
    final token = await tokenProvider();
    if (token.isEmpty) return null;
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return data['userId']?.toString() ?? data['sub']?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final token = await tokenProvider();
    await http.post(
      Uri.parse('$baseUrl/v1/conversations/$conversationId/read'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    final token = await tokenProvider();
    final response = await http.delete(
      Uri.parse('$baseUrl/v1/conversations/$conversationId/leave'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete conversation: ${response.statusCode}');
    }
  }
}
