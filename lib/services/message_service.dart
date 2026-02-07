import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/conversation.dart';

class MessageService {
  /// Base URL for the backend.
  ///
  /// - On web (Docker/nginx), the backend is exposed behind `/api/` and
  ///   proxied to the `backend` container on port 8080 (see `nginx.conf`).
  /// - On mobile/desktop during local development, the backend is usually
  ///   reachable on `http://localhost:8080`.
  static final String baseUrl = 'http://localhost:8080';

  // Get all conversations for a user
  static Future<List<Conversation>> getConversations(String userId) async {
    try {
      final uri = Uri.parse('$baseUrl/conversations/?userId=$userId');
      final response = await http.get(
        uri,
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return data.map((json) => Conversation.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching conversations: $e');
      return [];
    }
  }

  // Get messages in a conversation
  static Future<List<Message>> getConversationMessages(String conversationId) async {
    try {
      final uri = Uri.parse('$baseUrl/conversations/$conversationId/messages/');
      final response = await http.get(
        uri,
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return data.map((json) => Message.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  // Send a new message
  static Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/conversations/$conversationId/messages/');  // Updated to match backend route
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'conversationId': conversationId,
          'senderId': senderId,
          'content': content,
        }),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Message sent successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to send message',
      };
    } catch (e) {
      print('Error sending message: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Mark all messages in conversation as read
  static Future<Map<String, dynamic>> markConversationAsRead(
    String conversationId,
    String userId,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/conversations/$conversationId/read/');
      final response = await http.put(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Messages marked as read',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to mark messages as read',
      };
    } catch (e) {
      print('Error marking messages as read: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Create or get conversation between two users
  static Future<Map<String, dynamic>> getOrCreateConversation(
    String user1Id,
    String user2Id,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/conversations/');
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user1Id': user1Id,
          'user2Id': user2Id,
        }),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create conversation',
      };
    } catch (e) {
      print('Error creating conversation: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
