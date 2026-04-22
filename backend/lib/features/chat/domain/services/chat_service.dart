import '../../presentation/websocket/websocket_server.dart';
import '../../../../core/services/data_integrity_service.dart';
import '../../data/repositories/chat_repository.dart';

class ChatService {
  static final _repository = ChatRepository();

  static Future<Map<String, dynamic>> getConversations({
    required String userId,
    String? before,
    int limit = 50,
  }) async {
    try {
      final conversations = await _repository.getConversations(
        userId: userId,
        before: before,
        limit: limit,
      );

      return {
        'success': true,
        'conversations': conversations.map((c) => c.toJson()).toList(),
        'hasMore': conversations.length == limit
      };
    } catch (e) {
      print('Error getting conversations: $e');
      return {'success': false, 'message': 'Failed to get conversations: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMessages({
    required String conversationId,
    required String userId,
    String? before,
    int limit = 50,
  }) async {
    try {
      final messages = await _repository.getMessages(
        conversationId: conversationId,
        userId: userId,
        before: before,
        limit: limit,
      );
      print('[ChatService] Repository returned ${messages.length} messages for conv $conversationId');
      return {
        'success': true,
        'messages': messages.map((m) => m.toJson()).toList(),
        'hasMore': messages.length == limit
      };
    } catch (e, st) {
      print('Error getting messages: $e');
      print('Stack: $st');
      return {'success': false, 'message': 'Failed to get messages: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required String type,
    String? replyToId,
    String? clientMessageId,
    String? excludeConnectionId,
    List<String>? uploadIds,
    Map<String, dynamic>? voiceMetadata,
  }) async {
    try {
      // Validate uploads before heading to repository
      if (uploadIds != null && uploadIds.isNotEmpty) {
        final ok = await DataIntegrityService.validateUploadsForMessage(uploadIds);
        if (!ok) return {'success': false, 'message': 'One or more uploads are invalid or expired'};
      }

      final msgFinal = await _repository.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        type: type,
        replyToId: replyToId,
        clientMessageId: clientMessageId,
        uploadIds: uploadIds,
        voiceMetadata: voiceMetadata,
      );

      if (msgFinal['success'] == true) {
        WebSocketServer.broadcastToConversationMembers(
          conversationId,
          {
            'type': 'message:created',
            'payload': {'message': msgFinal['message']},
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          // P1 FIX: Remove user-level exclusion to allow multi-device synchronization.
          // Double UI bubbles on the active sender device are still prevented by 
          // passing the connection-specific ID in 'excludeConnectionId'.
          excludeUserId: null,
          excludeConnectionId: excludeConnectionId,
        );
      }

      return msgFinal;
    } catch (e) {
      print('Error sending message: $e');
      return {'success': false, 'message': 'Failed to send message: $e'};
    }
  }

  static Future<Map<String, dynamic>> markMessagesAsRead({required List<String> messageIds, required String userId}) async {
    try {
      await _repository.markMessagesAsRead(messageIds: messageIds, userId: userId);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Failed to mark messages as read: $e'};
    }
  }

  static Future<Map<String, dynamic>> markConversationAsRead({required String conversationId, required String userId}) async {
    try {
      await _repository.markConversationAsRead(conversationId: conversationId, userId: userId);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Failed to mark conversation as read: $e'};
    }
  }

  static const String SYSTEM_ID = '00000000-0000-0000-0000-000000000000';

  static Future<Map<String, dynamic>> leaveConversation({required String conversationId, required String userId}) async {
    try {
      final res = await _repository.leaveConversation(conversationId: conversationId, userId: userId);
      if (res['success'] == false) return res;

      if (res['type'] == 'group') {
        // P0 FIX: System message for leaving using a reserved SYSTEM_ID
        await sendMessage(
          conversationId: conversationId,
          senderId: SYSTEM_ID,
          content: 'User left the group',
          type: 'system'
        );
      }

      return {'success': true, 'message': 'Conversation history cleared'};
    } catch (e) {
      print('Error leaving conversation: $e');
      return {'success': false, 'message': 'Failed to leave conversation: $e'};
    }
  }

  static Future<Map<String, dynamic>> setTypingIndicator({required String conversationId, required String userId, required bool isTyping}) async {
    try {
      await _repository.setTypingIndicator(conversationId: conversationId, userId: userId, isTyping: isTyping);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Failed to set typing indicator: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTypingUsers(String conversationId, String userId) async {
    try {
      final users = await _repository.getTypingUsers(conversationId, userId);
      return {'success': true, 'typingUsers': users};
    } catch (e) {
      return {'success': false, 'message': 'Failed to get typing users: $e'};
    }
  }

  static Future<Map<String, dynamic>> createConversation({
    required String creatorId,
    required List<String> participantIds,
    required String type,
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final res = await _repository.createConversation(
        creatorId: creatorId,
        participantIds: participantIds,
        type: type,
        name: name,
        avatarUrl: avatarUrl,
      );
      
      if (res['exists'] == true) {
        return {
          'success': true, 
          'message': 'Conversation already exists', 
          'data': {'conversationId': res['id']}
        };
      }

      if (type == 'group') {
        await sendMessage(
          conversationId: res['id'],
          senderId: SYSTEM_ID,
          content: 'Group created',
          type: 'system'
        );
      }

      return {
        'success': true, 
        'message': 'Conversation created', 
        'data': {'conversationId': res['id']}
      };
    } catch (e) {
      print('Error in createConversation: $e');
      return {'success': false, 'message': 'Failed to create conversation: $e'};
    }
  }
}
