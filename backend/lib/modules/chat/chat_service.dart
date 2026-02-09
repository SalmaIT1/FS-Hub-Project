import 'dart:convert';
import 'package:mysql_client/mysql_client.dart';
import '../../database/db_connection.dart';
import '../chat/websocket_server.dart';

class ChatService {
  static Future<Map<String, dynamic>> getConversations({
    required int userId,
    String? before,
    int? limit = 50,
  }) async {
    try {
      final conn = DBConnection.getConnection();
      
      String query = '''
        SELECT DISTINCT c.id, c.name, c.type, c.created_at, c.updated_at,
               c.last_message_at, c.avatar_url,
               cm.last_read_at,
               (SELECT COUNT(*) FROM messages m 
                WHERE m.conversation_id = c.id 
                AND m.created_at > COALESCE(cm.last_read_at, '1970-01-01')
                AND m.sender_id != :userId) as unread_count,
               (SELECT m.content FROM messages m 
                WHERE m.conversation_id = c.id 
                ORDER BY m.created_at DESC 
                LIMIT 1) as last_message,
               (SELECT m.sender_id FROM messages m 
                WHERE m.conversation_id = c.id 
                ORDER BY m.created_at DESC 
                LIMIT 1) as last_message_sender_id,
               (SELECT u.username FROM messages m 
                JOIN users u ON m.sender_id = u.id
                WHERE m.conversation_id = c.id 
                ORDER BY m.created_at DESC 
                LIMIT 1) as last_message_sender_name
        FROM conversations c
        JOIN conversation_members cm ON c.id = cm.conversation_id
        WHERE cm.user_id = :userId
        AND cm.left_at IS NULL
        AND c.is_archived = FALSE
      ''';

      final params = <String, dynamic>{'userId': userId};

      if (before != null) {
        query += ' AND c.updated_at < :before';
        params['before'] = before;
      }

      query += ' ORDER BY c.last_message_at DESC, c.updated_at DESC';

      if (limit != null && limit > 0) {
        query += ' LIMIT $limit';
      }

      final result = await conn.execute(query, params);

      final conversations = result.rows.map((row) {
        return {
          'id': row.colByName('id').toString(),
          'name': row.colByName('name'),
          'type': row.colByName('type'),
          'avatarUrl': row.colByName('avatar_url'),
          'createdAt': row.colByName('created_at').toString(),
          'updatedAt': row.colByName('updated_at').toString(),
          'lastMessageAt': row.colByName('last_message_at')?.toString(),
          'lastMessage': row.colByName('last_message'),
          'lastMessageSenderId': row.colByName('last_message_sender_id')?.toString(),
          'lastMessageSenderName': row.colByName('last_message_sender_name'),
          'unreadCount': int.tryParse(row.colByName('unread_count').toString()) ?? 0,
          'participants': [], // Would need separate query
        };
      }).toList();

      return {
        'success': true,
        'conversations': conversations,
        'hasMore': conversations.length == (limit ?? 50),
        'cursor': conversations.isNotEmpty ? conversations.last['updatedAt'] : null,
      };
    } catch (e) {
      print('Error getting conversations: $e');
      return {
        'success': false,
        'message': 'Failed to get conversations: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getMessages({
    required String conversationId,
    String? before,
    int? limit = 50,
  }) async {
    try {
      final conn = DBConnection.getConnection();
      
      String query = '''
        SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type,
               m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at,
               u.username as sender_name, u.avatar_url as sender_avatar
        FROM messages m
        JOIN users u ON m.sender_id = u.id
        WHERE m.conversation_id = :conversationId
        AND m.is_deleted = FALSE
      ''';

      final params = {'conversationId': conversationId};

      if (before != null) {
        query += ' AND m.created_at < :before';
        params['before'] = before;
      }

      query += ' ORDER BY m.created_at DESC';

      if (limit != null && limit > 0) {
        query += ' LIMIT $limit';
      }

      final result = await conn.execute(query, params);

      final messages = result.rows.map((row) {
        return {
          'id': row.colByName('id').toString(),
          'conversationId': row.colByName('conversation_id').toString(),
          'senderId': row.colByName('sender_id').toString(),
          'senderName': row.colByName('sender_name'),
          'senderAvatar': row.colByName('sender_avatar'),
          'content': row.colByName('content'),
          'type': row.colByName('type'),
          'replyToId': row.colByName('reply_to_id')?.toString(),
          'isEdited': row.colByName('is_edited') == 1,
          'editedAt': row.colByName('edited_at')?.toString(),
          'createdAt': row.colByName('created_at').toString(),
          'updatedAt': row.colByName('updated_at').toString(),
          'isFromMe': false, // Set by frontend
          'attachments': [], // Would need separate query
          'voiceMessage': null, // Would need separate query
          'reactions': [], // Would need separate query
          'isRead': false, // Set by frontend
        };
      }).toList();

      return {
        'success': true,
        'messages': messages,
        'hasMore': messages.length == (limit ?? 50),
      };
    } catch (e) {
      print('Error getting messages: $e');
      return {
        'success': false,
        'message': 'Failed to get messages: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required int senderId,
    required String content,
    required String type,
    String? replyToId,
    String? clientMessageId,
  }) async {
    try {
      // Use a transaction when clientMessageId is provided to ensure
      // idempotent creation and avoid race conditions.
      if (clientMessageId != null && clientMessageId.isNotEmpty) {
        return await DBConnection.getConnection().transaction<Map<String, dynamic>>( (conn) async {
          // Verify membership under same connection
          final memberCheck = await conn.execute('''
            SELECT id FROM conversation_members 
            WHERE conversation_id = :conversationId AND user_id = :senderId 
            AND left_at IS NULL
          ''', {
            'conversationId': conversationId,
            'senderId': senderId,
          });

          if (memberCheck.rows.isEmpty) {
            return {
              'success': false,
              'message': 'User is not a member of this conversation',
            };
          }

          // Check idempotency mapping
          final existing = await conn.execute('''
            SELECT server_message_id FROM message_idempotency
            WHERE client_message_id = :clientMessageId AND conversation_id = :conversationId
            FOR UPDATE
          ''', {
            'clientMessageId': clientMessageId,
            'conversationId': conversationId,
          });

          if (existing.rows.isNotEmpty) {
            final serverMessageId = existing.rows.first.colByName('server_message_id');
            // Return existing message
            final messageResult = await conn.execute('''
              SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type,
                     m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at,
                     u.username as sender_name, u.avatar_url as sender_avatar
              FROM messages m
              JOIN users u ON m.sender_id = u.id
              WHERE m.id = :messageId
            ''', {'messageId': serverMessageId});

            if (messageResult.rows.isNotEmpty) {
              final row = messageResult.rows.first;
              final message = {
                'id': row.colByName('id').toString(),
                'clientMessageId': clientMessageId,
                'conversationId': row.colByName('conversation_id').toString(),
                'senderId': row.colByName('sender_id').toString(),
                'senderName': row.colByName('sender_name'),
                'senderAvatar': row.colByName('sender_avatar'),
                'content': row.colByName('content'),
                'type': row.colByName('type'),
                'replyToId': row.colByName('reply_to_id')?.toString(),
                'isEdited': row.colByName('is_edited') == 1,
                'editedAt': row.colByName('edited_at')?.toString(),
                'createdAt': row.colByName('created_at').toString(),
                'updatedAt': row.colByName('updated_at').toString(),
                'attachments': [],
                'voiceMessage': null,
                'reactions': [],
                'isRead': false,
              };

              return {'success': true, 'message': message};
            }
          }

          // Insert message
          final insertRes = await conn.execute('''
            INSERT INTO messages (conversation_id, sender_id, content, type, reply_to_id)
            VALUES (:conversationId, :senderId, :content, :type, :replyToId)
          ''', {
            'conversationId': conversationId,
            'senderId': senderId,
            'content': content,
            'type': type,
            'replyToId': replyToId,
          });

          final messageId = insertRes.lastInsertID;

          // Persist idempotency mapping
          await conn.execute('''
            INSERT INTO message_idempotency (client_message_id, conversation_id, server_message_id)
            VALUES (:clientMessageId, :conversationId, :serverMessageId)
          ''', {
            'clientMessageId': clientMessageId,
            'conversationId': conversationId,
            'serverMessageId': messageId,
          });

          // Retrieve the full message
          final messageResult = await conn.execute('''
            SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type,
                   m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at,
                   u.username as sender_name, u.avatar_url as sender_avatar
            FROM messages m
            JOIN users u ON m.sender_id = u.id
            WHERE m.id = :messageId
          ''', {'messageId': messageId});

          if (messageResult.rows.isNotEmpty) {
            final row = messageResult.rows.first;
            final message = {
              'id': row.colByName('id').toString(),
              'clientMessageId': clientMessageId,
              'conversationId': row.colByName('conversation_id').toString(),
              'senderId': row.colByName('sender_id').toString(),
              'senderName': row.colByName('sender_name'),
              'senderAvatar': row.colByName('sender_avatar'),
              'content': row.colByName('content'),
              'type': row.colByName('type'),
              'replyToId': row.colByName('reply_to_id')?.toString(),
              'isEdited': row.colByName('is_edited') == 1,
              'editedAt': row.colByName('edited_at')?.toString(),
              'createdAt': row.colByName('created_at').toString(),
              'updatedAt': row.colByName('updated_at').toString(),
              'attachments': [],
              'voiceMessage': null,
              'reactions': [],
              'isRead': false,
            };

            return {'success': true, 'message': message};
          }

          return {'success': false, 'message': 'Failed to persist message'};
        });
      }

      // Fallback: no clientMessageId provided — perform simple insert
      final conn = DBConnection.getConnection();
      
      // Verify user is member of conversation
      final memberCheck = await conn.execute('''
        SELECT id FROM conversation_members 
        WHERE conversation_id = :conversationId AND user_id = :senderId 
        AND left_at IS NULL
      ''', {
        'conversationId': conversationId,
        'senderId': senderId,
      });

      if (memberCheck.rows.isEmpty) {
        return {
          'success': false,
          'message': 'User is not a member of this conversation',
        };
      }

      // Insert message
      final result = await conn.execute('''
        INSERT INTO messages (conversation_id, sender_id, content, type, reply_to_id)
        VALUES (:conversationId, :senderId, :content, :type, :replyToId)
      ''', {
        'conversationId': conversationId,
        'senderId': senderId,
        'content': content,
        'type': type,
        'replyToId': replyToId,
      });

      final messageId = result.lastInsertID;

      // Get the complete message with sender info
      final messageResult = await conn.execute('''
        SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type,
               m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at,
               u.username as sender_name, u.avatar_url as sender_avatar
        FROM messages m
        JOIN users u ON m.sender_id = u.id
        WHERE m.id = :messageId
      ''', {'messageId': messageId});

      if (messageResult.rows.isNotEmpty) {
        final row = messageResult.rows.first;
        final message = {
          'id': row.colByName('id').toString(),
          'conversationId': row.colByName('conversation_id').toString(),
          'senderId': row.colByName('sender_id').toString(),
          'senderName': row.colByName('sender_name'),
          'senderAvatar': row.colByName('sender_avatar'),
          'content': row.colByName('content'),
          'type': row.colByName('type'),
          'replyToId': row.colByName('reply_to_id')?.toString(),
          'isEdited': row.colByName('is_edited') == 1,
          'editedAt': row.colByName('edited_at')?.toString(),
          'createdAt': row.colByName('created_at').toString(),
          'updatedAt': row.colByName('updated_at').toString(),
          'attachments': [],
          'voiceMessage': null,
          'reactions': [],
          'isRead': false,
        };

        return {
          'success': true,
          'message': message,
        };
      }

      return {
        'success': false,
        'message': 'Failed to retrieve sent message',
      };
    } catch (e) {
      print('Error sending message: $e');
      return {
        'success': false,
        'message': 'Failed to send message: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> markMessagesAsRead({
    required List<String> messageIds,
    required int userId,
  }) async {
    try {
      final conn = DBConnection.getConnection();
      
      for (final messageId in messageIds) {
        // Insert or update read receipt
        await conn.execute('''
          INSERT INTO message_reads (message_id, user_id, read_at)
          VALUES (:messageId, :userId, NOW())
          ON DUPLICATE KEY UPDATE read_at = NOW()
        ''', {
          'messageId': messageId,
          'userId': userId,
        });
      }

      return {
        'success': true,
        'message': 'Messages marked as read',
      };
    } catch (e) {
      print('Error marking messages as read: $e');
      return {
        'success': false,
        'message': 'Failed to mark messages as read: $e',
      };
    }
  }

  /// Mark all messages in a conversation as read for a given user.
  /// Also broadcasts read events to other connected participants.
  static Future<Map<String, dynamic>> markConversationAsRead({
    required String conversationId,
    required int userId,
  }) async {
    try {
      final conn = DBConnection.getConnection();

      // Update conversation_members.last_read_at for this user
      await conn.execute('''
        UPDATE conversation_members
        SET last_read_at = NOW()
        WHERE conversation_id = :conversationId AND user_id = :userId
      ''', {'conversationId': conversationId, 'userId': userId});

      // Find all messages in this conversation that the user hasn't read yet
      final res = await conn.execute('''
        SELECT m.id FROM messages m
        WHERE m.conversation_id = :conversationId
          AND m.sender_id != :userId
          AND m.id NOT IN (
            SELECT message_id FROM message_reads WHERE user_id = :userId
          )
      ''', {'conversationId': conversationId, 'userId': userId});

      final toMark = <String>[];
      for (final row in res.rows) {
        toMark.add(row.colByName('id').toString());
      }

      // Insert read receipts for each message
      for (final messageId in toMark) {
        await conn.execute('''
          INSERT INTO message_reads (message_id, user_id, read_at)
          VALUES (:messageId, :userId, NOW())
          ON DUPLICATE KEY UPDATE read_at = NOW()
        ''', {'messageId': messageId, 'userId': userId});

        // Broadcast a read event for this message to other participants
        WebSocketServer.broadcastToConversationMembers(
          conversationId,
          {
            'type': 'read',
            'payload': {
              'messageId': messageId,
              'readByUserId': userId.toString(),
              'readAt': DateTime.now().toIso8601String(),
            },
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          excludeUserId: userId.toString(),
        );
      }

      return {'success': true, 'marked': toMark.length};
    } catch (e) {
      print('Error marking conversation as read: $e');
      return {'success': false, 'message': 'Failed to mark conversation as read: $e'};
    }
  }

  static Future<Map<String, dynamic>> setTypingIndicator({
    required String conversationId,
    required int userId,
    required bool isTyping,
  }) async {
    try {
      final conn = DBConnection.getConnection();
      
      if (isTyping) {
        // Insert or update typing indicator
        await conn.execute('''
          INSERT INTO typing_events (conversation_id, user_id, is_typing, last_seen_at)
          VALUES (:conversationId, :userId, TRUE, NOW())
          ON DUPLICATE KEY UPDATE is_typing = TRUE, last_seen_at = NOW()
        ''', {
          'conversationId': conversationId,
          'userId': userId,
        });
      } else {
        // Remove typing indicator
        await conn.execute('''
          DELETE FROM typing_events 
          WHERE conversation_id = :conversationId AND user_id = :userId
        ''', {
          'conversationId': conversationId,
          'userId': userId,
        });
      }

      return {
        'success': true,
      };
    } catch (e) {
      print('Error setting typing indicator: $e');
      return {
        'success': false,
        'message': 'Failed to set typing indicator: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getTypingUsers(String conversationId) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT te.user_id, u.username, te.last_seen_at
        FROM typing_events te
        JOIN users u ON te.user_id = u.id
        WHERE te.conversation_id = :conversationId
        AND te.is_typing = TRUE
        AND te.last_seen_at > DATE_SUB(NOW(), INTERVAL 30 SECOND)
        ORDER BY te.last_seen_at DESC
      ''', {'conversationId': conversationId});

      final typingUsers = result.rows.map((row) => {
        'userId': row.colByName('user_id').toString(),
        'username': row.colByName('username'),
        'lastSeenAt': row.colByName('last_seen_at').toString(),
      }).toList();

      return {
        'success': true,
        'typingUsers': typingUsers,
      };
    } catch (e) {
      print('Error getting typing users: $e');
      return {
        'success': false,
        'message': 'Failed to get typing users: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createConversation({
    required int user1Id,
    required int user2Id,
    required String type,
    String? name,
  }) async {
    try {
      final conn = DBConnection.getConnection();

      // For direct conversations, check if one exists between these two users
      final checkQuery =
          'SELECT c.id FROM conversations c JOIN conversation_members cm1 ON c.id = cm1.conversation_id JOIN conversation_members cm2 ON c.id = cm2.conversation_id WHERE c.type = "direct" AND cm1.user_id = :user1Id AND cm2.user_id = :user2Id';

      try {
        final existing = await conn.execute(checkQuery, {
          'user1Id': user1Id,
          'user2Id': user2Id,
        });

        if (existing.rows.isNotEmpty) {
          final conversationId = existing.rows.first.colByName('id');
          // Conversation already exists, return it
          return {
            'success': true,
            'message': 'Conversation already exists',
            'data': {'conversationId': conversationId},
          };
        }
      } catch (e) {
        // Continue to create new conversation if check fails
      }

      // Create new conversation
      final insertResult = await conn.execute(
        '''
          INSERT INTO conversations (name, type, created_by, created_at, updated_at)
          VALUES (:name, :type, :createdBy, NOW(), NOW())
        ''',
        {
          'name': type == 'direct' ? null : name,
          'type': type,
          'createdBy': user1Id,
        },
      );

      final conversationId = insertResult.lastInsertID;

      // Add both users as conversation members
      await conn.execute(
        'INSERT INTO conversation_members (conversation_id, user_id, joined_at) VALUES (:conversationId, :user1Id, NOW())',
        {
          'conversationId': conversationId,
          'user1Id': user1Id,
        },
      );

      await conn.execute(
        'INSERT INTO conversation_members (conversation_id, user_id, joined_at) VALUES (:conversationId, :user2Id, NOW())',
        {
          'conversationId': conversationId,
          'user2Id': user2Id,
        },
      );

      print('Created conversation $conversationId between users $user1Id and $user2Id');

      return {
        'success': true,
        'message': 'Conversation created successfully',
        'data': {'conversationId': conversationId},
      };
    } catch (e) {
      print('Error creating conversation: $e');
      return {
        'success': false,
        'message': 'Failed to create conversation: $e',
      };
    }
  }
}
