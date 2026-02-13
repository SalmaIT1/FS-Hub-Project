import 'dart:convert';
import '../../database/db_connection.dart';
import '../chat/websocket_server.dart';
import '../../services/data_integrity_service.dart';

class ChatService {
  // Helper to build full message payload from a DB row
  static Future<Map<String, dynamic>> _buildMessageFromRow(dynamic row, dynamic conn) async {
    final messageId = row.colByName('id')?.toString();

    // Attachments
    final attRes = await conn.execute('''
      SELECT id, filename, original_filename, file_path, file_size, mime_type, thumbnail_path, created_at
      FROM message_attachments
      WHERE message_id = :messageId
    ''', {'messageId': messageId});

    final attachments = attRes.rows.map((r) {
      final sizeVal = int.tryParse(r.colByName('file_size')?.toString() ?? '0') ?? 0;
      final displaySize = sizeVal >= 1024 ? '${(sizeVal / 1024).toStringAsFixed(1)} KB' : '${sizeVal} B';
      final storedFilename = r.colByName('filename') ?? r.colByName('stored_filename');
      final thumbnailStored = r.colByName('thumbnail_path');
      final mimeType = r.colByName('mime_type') ?? 'application/octet-stream';
      String type = 'file';
      if (mimeType.startsWith('image/')) type = 'image';
      else if (mimeType.startsWith('video/')) type = 'video';
      else if (mimeType.startsWith('audio/')) type = 'audio';

      String mediaUrl = '';
      String? thumbnailUrl;
      if (storedFilename != null) mediaUrl = 'http://localhost:8080/media/${storedFilename}';
      if (thumbnailStored != null) thumbnailUrl = 'http://localhost:8080/media/${thumbnailStored}';

      return {
        'id': r.colByName('id')?.toString(),
        'type': type,
        'filename': r.colByName('original_filename') ?? storedFilename,
        'mimeType': mimeType,
        'file_size': sizeVal,
        'media_url': mediaUrl,
        'thumbnail_url': thumbnailUrl,
        'displaySize': displaySize,
      };
    }).toList();

    // Voice metadata (optional)
    Map<String, dynamic>? voiceMessage;
    try {
      final vm = await conn.execute('''
        SELECT id, file_path, duration_seconds, waveform_data, file_size, created_at
        FROM voice_messages
        WHERE message_id = :messageId
        LIMIT 1
      ''', {'messageId': messageId});
      if (vm.rows.isNotEmpty) {
        final v = vm.rows.first;
        // waveform_data might be stored as JSON/text; try to decode
        List<double> waveform = [];
        try {
          final wf = v.colByName('waveform_data');
          if (wf != null) {
            final parsed = wf is String ? jsonDecode(wf) : wf;
            if (parsed is List) waveform = parsed.map((e) => (e as num).toDouble()).toList();
          }
        } catch (_) {}

        final durationSec = v.colByName('duration_seconds');
        final storedVoice = v.colByName('file_path');
        String voiceMediaUrl = '';
        // storedVoice may be a filesystem path or stored filename; try to extract filename
        if (storedVoice != null) {
          // If storedVoice contains a path with '/', try to get basename
          final s = storedVoice.toString();
          final parts = s.split('/');
          final candidate = parts.isNotEmpty ? parts.last : s;
          voiceMediaUrl = 'http://localhost:8080/media/${candidate}';
        }
        voiceMessage = {
          'fileId': v.colByName('id')?.toString(),
          'duration_seconds': durationSec != null ? int.tryParse(durationSec.toString()) ?? 0 : 0,
          'waveform': waveform,
          'transcription': null,
          'media_url': voiceMediaUrl,
        };
      }
    } catch (_) {}

    return {
      'id': row.colByName('id')?.toString(),
      'conversationId': row.colByName('conversation_id')?.toString(),
      'senderId': row.colByName('sender_id')?.toString(),
      'senderName': row.colByName('sender_name'),
      'senderAvatar': row.colByName('sender_avatar'),
      'content': row.colByName('content'),
      'type': row.colByName('type'),
      'replyToId': row.colByName('reply_to_id')?.toString(),
      'isEdited': row.colByName('is_edited') == 1,
      'editedAt': row.colByName('edited_at')?.toString(),
      'createdAt': row.colByName('created_at')?.toString(),
      'updatedAt': row.colByName('updated_at')?.toString(),
      'attachments': attachments,
      'voiceMessage': voiceMessage,
      'reactions': [],
      'isRead': false,
    };
  }

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
      if (limit != null && limit > 0) query += ' LIMIT $limit';

      final res = await conn.execute(query, params);
      final conversations = res.rows.map((r) => {
        'id': r.colByName('id')?.toString(),
        'name': r.colByName('name'),
        'type': r.colByName('type'),
        'avatarUrl': r.colByName('avatar_url'),
        'createdAt': r.colByName('created_at')?.toString(),
        'updatedAt': r.colByName('updated_at')?.toString(),
        'lastMessageAt': r.colByName('last_message_at')?.toString(),
        'lastMessage': r.colByName('last_message'),
        'lastMessageSenderId': r.colByName('last_message_sender_id')?.toString(),
        'lastMessageSenderName': r.colByName('last_message_sender_name'),
        'unreadCount': int.tryParse(r.colByName('unread_count')?.toString() ?? '0') ?? 0,
      }).toList();

      return {'success': true, 'conversations': conversations, 'hasMore': conversations.length == (limit ?? 50)};
    } catch (e) {
      print('Error getting conversations: $e');
      return {'success': false, 'message': 'Failed to get conversations: $e'};
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
      if (limit != null && limit > 0) query += ' LIMIT $limit';

      final res = await conn.execute(query, params);
      final messages = <Map<String, dynamic>>[];
      for (final row in res.rows) {
        final message = await _buildMessageFromRow(row, conn);
        messages.add(message);
      }

      return {'success': true, 'messages': messages, 'hasMore': messages.length == (limit ?? 50)};
    } catch (e) {
      print('Error getting messages: $e');
      return {'success': false, 'message': 'Failed to get messages: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required int senderId,
    required String content,
    required String type,
    String? replyToId,
    String? clientMessageId,
    List<String>? uploadIds,
    Map<String, dynamic>? voiceMetadata,
  }) async {
    try {
      final conn = DBConnection.getConnection();

      // transactional idempotent flow
      if (clientMessageId != null && clientMessageId.isNotEmpty) {
        return await conn.transaction<Map<String, dynamic>>((tx) async {
          // membership
          final member = await tx.execute('''
            SELECT id FROM conversation_members WHERE conversation_id = :conversationId AND user_id = :senderId AND left_at IS NULL
          ''', {'conversationId': conversationId, 'senderId': senderId});
          if (member.rows.isEmpty) return {'success': false, 'message': 'User is not a member of this conversation'};

          // idempotency
          final existing = await tx.execute('''
            SELECT server_message_id FROM message_idempotency WHERE client_message_id = :clientMessageId AND conversation_id = :conversationId FOR UPDATE
          ''', {'clientMessageId': clientMessageId, 'conversationId': conversationId});
          if (existing.rows.isNotEmpty) {
            final serverMessageId = existing.rows.first.colByName('server_message_id');
            final msgRes = await tx.execute('''
              SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type, m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at, u.username as sender_name, u.avatar_url as sender_avatar
              FROM messages m JOIN users u ON m.sender_id = u.id WHERE m.id = :messageId
            ''', {'messageId': serverMessageId});
            if (msgRes.rows.isNotEmpty) {
              final mrow = msgRes.rows.first;
              final built = await _buildMessageFromRow(mrow, tx);
              built['clientMessageId'] = clientMessageId;
              return {'success': true, 'message': built};
            }
          }

          // insert message
          final insert = await tx.execute('''
            INSERT INTO messages (conversation_id, sender_id, content, type, reply_to_id, created_at, updated_at)
            VALUES (:conversationId, :senderId, :content, :type, :replyToId, NOW(), NOW())
          ''', {'conversationId': conversationId, 'senderId': senderId, 'content': content, 'type': type, 'replyToId': replyToId});
          final messageId = insert.lastInsertID;

          // validate uploads
          if (uploadIds != null && uploadIds.isNotEmpty) {
            final ok = await DataIntegrityService.validateUploadsForMessage(uploadIds);
            if (!ok) return {'success': false, 'message': 'One or more uploads are invalid or expired'};
            await DataIntegrityService.markUploadsAsUsed(uploadIds);
          }

          // bind attachments
          if (uploadIds != null && uploadIds.isNotEmpty) {
            for (final uploadId in uploadIds) {
              final up = await tx.execute('''
                SELECT id, original_filename, stored_filename, file_path, file_size, mime_type FROM file_uploads WHERE id = :uploadId
              ''', {'uploadId': uploadId});
              if (up.rows.isNotEmpty) {
                final u = up.rows.first;
                await tx.execute('''
                  INSERT INTO message_attachments (message_id, filename, original_filename, file_path, file_size, mime_type, created_at)
                  VALUES (:messageId, :storedFilename, :originalFilename, :filePath, :fileSize, :mimeType, NOW())
                ''', {
                  'messageId': messageId,
                  'storedFilename': u.colByName('stored_filename'),
                  'originalFilename': u.colByName('original_filename'),
                  'filePath': u.colByName('file_path'),
                  'fileSize': u.colByName('file_size'),
                  'mimeType': u.colByName('mime_type'),
                });
              }
            }
          }

          // Handle voice message metadata
          if (type == 'voice' && voiceMetadata != null && uploadIds != null && uploadIds.isNotEmpty) {
            // Get file_path from the uploaded file
            final uploadId = uploadIds.first;
            final up = await tx.execute('''
              SELECT id, file_path, file_size FROM file_uploads WHERE id = :uploadId
            ''', {'uploadId': uploadId});
            if (up.rows.isNotEmpty) {
              final u = up.rows.first;
              final filePath = u.colByName('file_path');
              final fileSize = u.colByName('file_size');
              final durationSeconds = voiceMetadata['duration_seconds'] ?? 0;
              final waveformData = voiceMetadata['waveform_data'] ?? '';
              
              // Ensure waveform_data is valid JSON (wrap in quotes if it's a plain string)
              String waveformDataValue;
              if (waveformData is String) {
                // If it looks like JSON, use as-is, otherwise wrap as JSON string
                if (waveformData.startsWith('[') || waveformData.startsWith('{')) {
                  waveformDataValue = waveformData;
                } else {
                  waveformDataValue = '"$waveformData"';
                }
              } else {
                waveformDataValue = 'null';
              }
              
              await tx.execute('''
                INSERT INTO voice_messages (message_id, file_path, duration_seconds, waveform_data, file_size, created_at)
                VALUES (:messageId, :filePath, :durationSeconds, :waveformData, :fileSize, NOW())
              ''', {
                'messageId': messageId,
                'filePath': filePath,
                'durationSeconds': durationSeconds,
                'waveformData': waveformDataValue,
                'fileSize': fileSize,
              });
            }
          }

          // persist idempotency
          await tx.execute('''
            INSERT INTO message_idempotency (client_message_id, conversation_id, server_message_id)
            VALUES (:clientMessageId, :conversationId, :serverMessageId)
          ''', {'clientMessageId': clientMessageId, 'conversationId': conversationId, 'serverMessageId': messageId});

          // return built message
          final msgRes = await tx.execute('''
            SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type, m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at, u.username as sender_name, u.avatar_url as sender_avatar
            FROM messages m JOIN users u ON m.sender_id = u.id WHERE m.id = :messageId
          ''', {'messageId': messageId});
          if (msgRes.rows.isNotEmpty) {
            final built = await _buildMessageFromRow(msgRes.rows.first, tx);
            built['clientMessageId'] = clientMessageId;
            return {'success': true, 'message': built};
          }

          return {'success': false, 'message': 'Failed to persist message'};
        });
      }

      // non-idempotent
      final member = await conn.execute('''
        SELECT id FROM conversation_members WHERE conversation_id = :conversationId AND user_id = :senderId AND left_at IS NULL
      ''', {'conversationId': conversationId, 'senderId': senderId});
      if (member.rows.isEmpty) return {'success': false, 'message': 'User is not a member of this conversation'};

      final insert = await conn.execute('''
        INSERT INTO messages (conversation_id, sender_id, content, type, reply_to_id, created_at, updated_at)
        VALUES (:conversationId, :senderId, :content, :type, :replyToId, NOW(), NOW())
      ''', {'conversationId': conversationId, 'senderId': senderId, 'content': content, 'type': type, 'replyToId': replyToId});
      final messageId = insert.lastInsertID;

      if (uploadIds != null && uploadIds.isNotEmpty) {
        final ok = await DataIntegrityService.validateUploadsForMessage(uploadIds);
        if (!ok) return {'success': false, 'message': 'One or more uploads are invalid or expired'};
        await DataIntegrityService.markUploadsAsUsed(uploadIds);
        for (final uploadId in uploadIds) {
          final up = await conn.execute('''SELECT id, original_filename, stored_filename, file_path, file_size, mime_type FROM file_uploads WHERE id = :uploadId''', {'uploadId': uploadId});
          if (up.rows.isNotEmpty) {
            final u = up.rows.first;
            await conn.execute('''INSERT INTO message_attachments (message_id, filename, original_filename, file_path, file_size, mime_type, created_at) VALUES (:messageId, :storedFilename, :originalFilename, :filePath, :fileSize, :mimeType, NOW())''', {
              'messageId': messageId,
              'storedFilename': u.colByName('stored_filename'),
              'originalFilename': u.colByName('original_filename'),
              'filePath': u.colByName('file_path'),
              'fileSize': u.colByName('file_size'),
              'mimeType': u.colByName('mime_type'),
            });
          }
        }
        
        // Handle voice message metadata
        if (type == 'voice' && voiceMetadata != null) {
          final uploadId = uploadIds.first;
          final up = await conn.execute('''SELECT id, file_path, file_size FROM file_uploads WHERE id = :uploadId''', {'uploadId': uploadId});
          if (up.rows.isNotEmpty) {
            final u = up.rows.first;
            final filePath = u.colByName('file_path');
            final fileSize = u.colByName('file_size');
            final durationSeconds = voiceMetadata['duration_seconds'] ?? 0;
            final waveformData = voiceMetadata['waveform_data'] ?? '';
            
            // Ensure waveform_data is valid JSON (wrap in quotes if it's a plain string)
            String waveformDataValue;
            if (waveformData is String) {
              if (waveformData.startsWith('[') || waveformData.startsWith('{')) {
                waveformDataValue = waveformData;
              } else {
                waveformDataValue = '"$waveformData"';
              }
            } else {
              waveformDataValue = 'null';
            }
            
            await conn.execute('''
              INSERT INTO voice_messages (message_id, file_path, duration_seconds, waveform_data, file_size, created_at)
              VALUES (:messageId, :filePath, :durationSeconds, :waveformData, :fileSize, NOW())
            ''', {
              'messageId': messageId,
              'filePath': filePath,
              'durationSeconds': durationSeconds,
              'waveformData': waveformDataValue,
              'fileSize': fileSize,
            });
          }
        }
      }

      final msgRes = await conn.execute('''
        SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type, m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at, u.username as sender_name, u.avatar_url as sender_avatar
        FROM messages m JOIN users u ON m.sender_id = u.id WHERE m.id = :messageId
      ''', {'messageId': messageId});
      if (msgRes.rows.isNotEmpty) {
        final built = await _buildMessageFromRow(msgRes.rows.first, conn);
        return {'success': true, 'message': built};
      }

      return {'success': false, 'message': 'Failed to retrieve sent message'};
    } catch (e) {
      print('Error sending message: $e');
      return {'success': false, 'message': 'Failed to send message: $e'};
    }
  }

  static Future<Map<String, dynamic>> markMessagesAsRead({required List<String> messageIds, required int userId}) async {
    try {
      final conn = DBConnection.getConnection();
      for (final id in messageIds) {
        await conn.execute('''
          INSERT INTO message_reads (message_id, user_id, read_at) VALUES (:messageId, :userId, NOW()) ON DUPLICATE KEY UPDATE read_at = NOW()
        ''', {'messageId': id, 'userId': userId});
      }
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Failed to mark messages as read: $e'};
    }
  }

  static Future<Map<String, dynamic>> markConversationAsRead({required String conversationId, required int userId}) async {
    try {
      final conn = DBConnection.getConnection();
      await conn.execute('''UPDATE conversation_members SET last_read_at = NOW() WHERE conversation_id = :conversationId AND user_id = :userId''', {'conversationId': conversationId, 'userId': userId});
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Failed to mark conversation as read: $e'};
    }
  }

  static Future<Map<String, dynamic>> setTypingIndicator({required String conversationId, required int userId, required bool isTyping}) async {
    try {
      final conn = DBConnection.getConnection();
      if (isTyping) {
        await conn.execute('''INSERT INTO typing_events (conversation_id, user_id, is_typing, last_seen_at) VALUES (:conversationId, :userId, TRUE, NOW()) ON DUPLICATE KEY UPDATE is_typing = TRUE, last_seen_at = NOW()''', {'conversationId': conversationId, 'userId': userId});
      } else {
        await conn.execute('''DELETE FROM typing_events WHERE conversation_id = :conversationId AND user_id = :userId''', {'conversationId': conversationId, 'userId': userId});
      }
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Failed to set typing indicator: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTypingUsers(String conversationId) async {
    try {
      final conn = DBConnection.getConnection();
      final res = await conn.execute('''SELECT te.user_id, u.username, te.last_seen_at FROM typing_events te JOIN users u ON te.user_id = u.id WHERE te.conversation_id = :conversationId AND te.is_typing = TRUE AND te.last_seen_at > DATE_SUB(NOW(), INTERVAL 30 SECOND) ORDER BY te.last_seen_at DESC''', {'conversationId': conversationId});
      final users = res.rows.map((r) => {'userId': r.colByName('user_id')?.toString(), 'username': r.colByName('username'), 'lastSeenAt': r.colByName('last_seen_at')?.toString()}).toList();
      return {'success': true, 'typingUsers': users};
    } catch (e) {
      return {'success': false, 'message': 'Failed to get typing users: $e'};
    }
  }

  static Future<Map<String, dynamic>> createConversation({required int user1Id, required int user2Id, required String type, String? name}) async {
    try {
      final conn = DBConnection.getConnection();
      final existing = await conn.execute('''SELECT c.id FROM conversations c JOIN conversation_members cm1 ON c.id = cm1.conversation_id JOIN conversation_members cm2 ON c.id = cm2.conversation_id WHERE c.type = :type AND cm1.user_id = :user1Id AND cm2.user_id = :user2Id''', {'type': 'direct', 'user1Id': user1Id, 'user2Id': user2Id});
      if (existing.rows.isNotEmpty) return {'success': true, 'message': 'Conversation already exists', 'data': {'conversationId': existing.rows.first.colByName('id')}};
      final insert = await conn.execute('''INSERT INTO conversations (name, type, created_by, created_at, updated_at) VALUES (:name, :type, :createdBy, NOW(), NOW())''', {'name': type == 'direct' ? null : name, 'type': type, 'createdBy': user1Id});
      final conversationId = insert.lastInsertID;
      await conn.execute('''INSERT INTO conversation_members (conversation_id, user_id, joined_at) VALUES (:conversationId, :user1Id, NOW())''', {'conversationId': conversationId, 'user1Id': user1Id});
      await conn.execute('''INSERT INTO conversation_members (conversation_id, user_id, joined_at) VALUES (:conversationId, :user2Id, NOW())''', {'conversationId': conversationId, 'user2Id': user2Id});
      return {'success': true, 'message': 'Conversation created', 'data': {'conversationId': conversationId}};
    } catch (e) {
      return {'success': false, 'message': 'Failed to create conversation: $e'};
    }
  }
}
