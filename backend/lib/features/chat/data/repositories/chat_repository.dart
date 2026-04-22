import '../../../../shared/database/connection.dart';
import '../models/chat_attachment_model.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/voice_message_model.dart';
import '../../presentation/websocket/websocket_server.dart';
import 'dart:convert';

class ChatRepository {
  final _db = DBConnection.getConnection();

  Future<List<ConversationModel>> getConversations({
    required String userId,
    String? before,
    int limit = 50,
  }) async {
    limit = limit > 200 ? 200 : limit;
    String query = '''
      SELECT DISTINCT c.id, c.name, c.type, c.created_at, c.updated_at,
             c.last_message_at, c.avatar_url,
             cm.last_read_at, cm.history_cleared_at,
             (SELECT COUNT(*) FROM messages m 
              WHERE m.conversation_id = c.id 
              AND m.created_at > COALESCE(cm.last_read_at, '1970-01-01')
              AND (cm.history_cleared_at IS NULL OR m.created_at > cm.history_cleared_at)
              AND m.sender_id != :userId) as unread_count,
             (SELECT m.content FROM messages m 
              WHERE m.conversation_id = c.id 
              AND (cm.history_cleared_at IS NULL OR m.created_at > cm.history_cleared_at)
              ORDER BY m.created_at DESC 
              LIMIT 1) as last_message,
             (SELECT m.sender_id FROM messages m 
              WHERE m.conversation_id = c.id 
              AND (cm.history_cleared_at IS NULL OR m.created_at > cm.history_cleared_at)
              ORDER BY m.created_at DESC 
              LIMIT 1) as last_message_sender_id,
             (SELECT u.username FROM messages m 
              JOIN users u ON m.sender_id = u.id
              WHERE m.conversation_id = c.id 
              AND (cm.history_cleared_at IS NULL OR m.created_at > cm.history_cleared_at)
              ORDER BY m.created_at DESC 
              LIMIT 1) as last_message_sender_name
      FROM conversations c
      JOIN conversation_members cm ON c.id = cm.conversation_id
      WHERE cm.user_id = :userId
      AND (c.type = 'direct' OR cm.left_at IS NULL)
      AND (cm.history_cleared_at IS NULL OR c.last_message_at > cm.history_cleared_at)
      AND c.is_archived = FALSE
    ''';

    final params = <String, dynamic>{'userId': userId};
    if (before != null) {
      query += ' AND c.updated_at < :before';
      params['before'] = before;
    }
    query += ' ORDER BY c.last_message_at DESC, c.updated_at DESC';
    query += ' LIMIT $limit';

    final res = await _db.execute(query, params);
    if (res.rows.isEmpty) return [];

    // ── P2 N+1 FIX ──────────────────────────────────────────────────────────
    // Previously: 3 DB queries per conversation row (N×3 total).
    // Now: 2 additional bulk IN-clause queries for the entire result set → O(3) total.

    final convRows = res.rows.toList();
    final allConvIds = convRows
        .map((r) => r.colByName('id')?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    // Build parameterized IN clause for all conversation IDs.
    final idParams = <String, dynamic>{'myUserId': userId};
    final idPlaceholders = <String>[];
    for (int i = 0; i < allConvIds.length; i++) {
      idParams['cid$i'] = allConvIds[i];
      idPlaceholders.add(':cid$i');
    }
    final inClause = idPlaceholders.join(',');

    // BATCH QUERY 1: Fetch the "other member" info for all direct conversations.
    final otherMembersRes = await _db.execute('''
      SELECT cm.conversation_id, cm.user_id, u.is_online,
             e.prenom, e.nom, e.photo
      FROM conversation_members cm
      JOIN users u ON cm.user_id = u.id
      LEFT JOIN employees e ON u.id = e.user_id
      WHERE cm.conversation_id IN ($inClause)
        AND cm.user_id != :myUserId
        AND cm.left_at IS NULL
    ''', idParams);

    final otherMembersMap = <String, Map<String, dynamic>>{};
    for (final r in otherMembersRes.rows) {
      final convId = r.colByName('conversation_id')?.toString() ?? '';
      // Keep only the first other member per conversation (direct chats have exactly 2 members).
      if (!otherMembersMap.containsKey(convId)) {
        otherMembersMap[convId] = {
          'user_id': r.colByName('user_id')?.toString(),
          'is_online': r.colByName('is_online'),
          'prenom': r.colByName('prenom')?.toString().trim() ?? '',
          'nom': r.colByName('nom')?.toString().trim() ?? '',
          'photo': r.colByName('photo')?.toString().trim() ?? '',
        };
      }
    }

    // BATCH QUERY 2: Fetch all participant IDs for presence matching on the frontend.
    final participantsRes = await _db.execute('''
      SELECT conversation_id, user_id
      FROM conversation_members
      WHERE conversation_id IN ($inClause)
        AND left_at IS NULL
    ''', idParams);

    final participantsMap = <String, List<String>>{};
    for (final r in participantsRes.rows) {
      final convId = r.colByName('conversation_id')?.toString() ?? '';
      participantsMap.putIfAbsent(convId, () => []).add(
          r.colByName('user_id')?.toString() ?? '');
    }
    // ────────────────────────────────────────────────────────────────────────

    final conversations = <ConversationModel>[];
    for (final r in convRows) {
      final convType = r.colByName('type') ?? 'group';
      final convId = r.colByName('id')?.toString() ?? '';

      String? displayName = r.colByName('name');
      String? displayAvatarUrl = r.colByName('avatar_url');
      String? receiverId;
      bool isOnline = false;

      if (convType == 'direct') {
        final other = otherMembersMap[convId];
        if (other != null) {
          receiverId = other['user_id']?.toString();
          final onlineVal = other['is_online']?.toString();
          isOnline = onlineVal == '1' || onlineVal == 'true';

          final prenom = other['prenom']?.toString() ?? '';
          final nom = other['nom']?.toString() ?? '';
          final photo = other['photo']?.toString() ?? '';
          final fullName = [prenom, nom].where((s) => s.isNotEmpty).join(' ').trim();
          if (fullName.isNotEmpty) displayName = fullName;
          displayAvatarUrl = _normalizePhoto(photo);
        }
      }

      final participantIds = participantsMap[convId] ?? [];

      conversations.add(ConversationModel(
        id: convId,
        name: displayName ?? (convType == 'direct' ? receiverId : 'Group'),
        type: convType,
        avatarUrl: displayAvatarUrl,
        receiverId: receiverId,
        isOnline: isOnline,
        createdAt: r.colByName('created_at')?.toString(),
        updatedAt: r.colByName('updated_at')?.toString(),
        lastMessageAt: r.colByName('last_message_at')?.toString(),
        lastMessage: r.colByName('last_message'),
        lastMessageSenderId: r.colByName('last_message_sender_id')?.toString(),
        lastMessageSenderName: r.colByName('last_message_sender_name'),
        unreadCount: int.tryParse(r.colByName('unread_count')?.toString() ?? '0') ?? 0,
        participantIds: participantIds,
      ));
    }
    return conversations;
  }

  Future<List<ChatMessageModel>> getMessages({
    required String conversationId,
    required String userId,
    String? before,
    int limit = 50,
  }) async {
    limit = limit > 200 ? 200 : limit;
    String query = '''
      SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type,
             m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at,
             mi.client_message_id,
             COALESCE(CONCAT(e.prenom, ' ', e.nom), u.username) as sender_name,
             COALESCE(e.photo, u.avatar_url) as sender_avatar
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      LEFT JOIN employees e ON u.id = e.user_id
      JOIN conversation_members cm ON m.conversation_id = cm.conversation_id
      LEFT JOIN message_idempotency mi ON m.id = mi.server_message_id
      WHERE m.conversation_id = :conversationId
      AND cm.user_id = :userId
      AND m.is_deleted = FALSE
      AND (cm.history_cleared_at IS NULL OR m.created_at > cm.history_cleared_at)
    ''';

    final params = <String, dynamic>{
      'conversationId': conversationId,
      'userId': userId,
    };
    if (before != null) {
      query += ' AND m.created_at < :before';
      params['before'] = before;
    }
    query += ' ORDER BY m.created_at DESC LIMIT $limit';

    final res = await _db.execute(query, params);
    print('[ChatRepository] Fetching messages for conv $conversationId. Found ${res.rows.length} rows.');
    final rows = res.rows.toList();
    if (rows.isEmpty) return [];

    final messageIds = rows.map((r) => r.colByName('id')?.toString() ?? '').toList();
    final attPlaceholders = List.generate(messageIds.length, (i) => ':p$i').join(',');
    final attParams = <String, dynamic>{};
    for (var i = 0; i < messageIds.length; i++) {
        attParams['p$i'] = messageIds[i];
    }

    // Attachments
    final attRes = await _db.execute('''
      SELECT message_id, id, filename, original_filename, file_size, mime_type, thumbnail_path, created_at
      FROM message_attachments
      WHERE message_id IN ($attPlaceholders)
    ''', attParams);

    final attMap = <String, List<ChatAttachmentModel>>{};
    for (final r in attRes.rows) {
      final msgId = r.colByName('message_id')?.toString() ?? '';
      final size = int.tryParse(r.colByName('file_size')?.toString() ?? '0') ?? 0;
      final mime = r.colByName('mime_type') ?? '';
      final stored = r.colByName('filename')?.toString();
      
      attMap.putIfAbsent(msgId, () => []).add(ChatAttachmentModel(
        id: r.colByName('id')?.toString() ?? '',
        type: mime.startsWith('image/') ? 'image' : mime.startsWith('video/') ? 'video' : 'file',
        filename: r.colByName('original_filename') ?? stored ?? 'file',
        mimeType: mime,
        fileSize: size,
        mediaUrl: stored != null ? '/media/$stored' : '',
        thumbnailUrl: r.colByName('thumbnail_path')?.toString(),
        displaySize: size >= 1024 ? '${(size / 1024).toStringAsFixed(1)} KB' : '$size B',
      ));
    }

    // Voice
    final vmRes = await _db.execute('''
      SELECT message_id, id, file_path, duration, created_at
      FROM message_voice_messages
      WHERE message_id IN ($attPlaceholders)
    ''', attParams);

    final voiceMap = <String, VoiceMessageModel>{};
    for (final v in vmRes.rows) {
      final msgId = v.colByName('message_id')?.toString() ?? '';
      final path = v.colByName('file_path')?.toString() ?? '';
      voiceMap[msgId] = VoiceMessageModel(
        fileId: v.colByName('id')?.toString() ?? '',
        durationSeconds: int.tryParse(v.colByName('duration')?.toString() ?? '0') ?? 0,
        waveform: [], // Waveform would need JSON parse if stored
        mediaUrl: '/media/${path.split('/').last}',
      );
    }

    return rows.map<ChatMessageModel>((row) {
      final id = row.colByName('id')?.toString() ?? '';
      return ChatMessageModel(
        id: id,
        clientMessageId: row.colByName('client_message_id')?.toString(),
        conversationId: row.colByName('conversation_id')?.toString() ?? '',
        senderId: row.colByName('sender_id')?.toString() ?? '',
        senderName: row.colByName('sender_name'),
        senderAvatar: _normalizePhoto(row.colByName('sender_avatar')),
        content: row.colByName('content') ?? '',
        type: row.colByName('type') ?? 'text',
        replyToId: row.colByName('reply_to_id')?.toString(),
        isEdited: row.colByName('is_edited') == '1',
        editedAt: row.colByName('edited_at')?.toString(),
        createdAt: row.colByName('created_at')?.toString(),
        updatedAt: row.colByName('updated_at')?.toString(),
        attachments: attMap[id] ?? [],
        voiceMessage: voiceMap[id],
        reactions: [],
        isRead: false,
      );
    }).toList().reversed.toList();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required String type,
    String? replyToId,
    String? clientMessageId,
    List<String>? uploadIds,
    Map<String, dynamic>? voiceMetadata,
  }) async {
    // transactional idempotent flow
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      return await _db.transaction<Map<String, dynamic>>((tx) async {
        // membership
        final member = await tx.execute('''
          SELECT id FROM conversation_members WHERE conversation_id = :conversationId AND user_id = :senderId AND left_at IS NULL
        ''', {'conversationId': conversationId, 'senderId': senderId});
        if (member.rows.isEmpty) return {'success': false, 'message': 'User is not a member of this conversation'};

        // idempotency
        final existing = await tx.execute('''
          SELECT server_message_id FROM message_idempotency WHERE client_message_id = :clientMessageId AND conversation_id = :conversationId
        ''', {'clientMessageId': clientMessageId, 'conversationId': conversationId});
        if (existing.rows.isNotEmpty) {
          final serverMessageId = existing.rows.first.colByName('server_message_id');
          final msgRes = await tx.execute('''
            SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type, m.reply_to_id, m.is_edited, m.edited_at, m.created_at, m.updated_at, u.username as sender_name, u.avatar_url as sender_avatar
            FROM messages m JOIN users u ON m.sender_id = u.id WHERE m.id = :messageId
          ''', {'messageId': serverMessageId});
          if (msgRes.rows.isNotEmpty) {
            final built = await _buildMessageFromRow(msgRes.rows.first, tx);
            built['clientMessageId'] = clientMessageId;
            return {'success': true, 'message': built};
          }
        }

        // insert message
        final insert = await tx.execute('''
          INSERT INTO messages (conversation_id, sender_id, content, type, reply_to_id, created_at, updated_at)
          VALUES (:conversationId, :senderId, :content, :type, :replyToId, NOW(), NOW())
        ''', {
          'conversationId': conversationId, 
          'senderId': senderId, 
          'content': content, 
          'type': type, 
          'replyToId': replyToId
        });
        final messageId = insert.lastInsertID.toInt();

        // bind attachments
        if (uploadIds != null && uploadIds.isNotEmpty) {
          final params = <String, dynamic>{};
          final placeholders = [];
          for (int i = 0; i < uploadIds.length; i++) {
            final key = 'id$i';
            placeholders.add(':$key');
            params[key] = uploadIds[i];
          }
          await tx.execute(
            "UPDATE file_uploads SET is_completed = TRUE, expires_at = DATE_ADD(NOW(), INTERVAL 1 YEAR) WHERE id IN (${placeholders.join(',')})",
            params
          );

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
            await tx.execute('''
              INSERT INTO message_voice_messages (message_id, file_path, duration, waveform_data, file_size, created_at)
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

        // Update conversation timestamp
        await tx.execute(
          'UPDATE conversations SET last_message_at = NOW(), updated_at = NOW() WHERE id = :conversationId',
          {'conversationId': conversationId}
        );

        // return built message
        final msgRes = await tx.execute('''
          SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type, m.reply_to_id, 
                 m.is_edited, m.edited_at, m.created_at, m.updated_at, 
                 u.username as sender_name, u.avatar_url as sender_avatar,
                 mi.client_message_id
          FROM messages m 
          JOIN users u ON m.sender_id = u.id 
          LEFT JOIN message_idempotency mi ON m.id = mi.server_message_id
          WHERE m.id = :messageId
        ''', {'messageId': messageId});
        if (msgRes.rows.isNotEmpty) {
          final builtRow = msgRes.rows.first;
          final built = await _buildMessageFromRow(builtRow, tx);
          return {'success': true, 'message': built};
        }
        return {'success': false, 'message': 'Failed to persist message'};
      });
    } else {
       // Non-idempotent flow (legacy/standard)
       final member = await _db.execute('''
        SELECT id FROM conversation_members WHERE conversation_id = :conversationId AND user_id = :senderId AND left_at IS NULL
      ''', {'conversationId': conversationId, 'senderId': senderId});
      if (member.rows.isEmpty) return {'success': false, 'message': 'User is not a member of this conversation'};

      final insert = await _db.execute('''
        INSERT INTO messages (conversation_id, sender_id, content, type, reply_to_id, created_at, updated_at)
        VALUES (:conversationId, :senderId, :content, :type, :replyToId, NOW(), NOW())
      ''', {
        'conversationId': conversationId, 
        'senderId': senderId, 
        'content': content, 
        'type': type, 
        'replyToId': replyToId
      });
      final messageId = insert.lastInsertID.toInt();

      if (uploadIds != null && uploadIds.isNotEmpty) {
          final params = <String, dynamic>{};
          final placeholders = [];
          for (int i = 0; i < uploadIds.length; i++) {
            final key = 'id$i';
            placeholders.add(':$key');
            params[key] = uploadIds[i];
          }
          await _db.execute(
            "UPDATE file_uploads SET is_completed = TRUE, expires_at = DATE_ADD(NOW(), INTERVAL 1 YEAR) WHERE id IN (${placeholders.join(',')})",
            params
          );

        for (final uploadId in uploadIds) {
          final up = await _db.execute('''SELECT id, original_filename, stored_filename, file_path, file_size, mime_type FROM file_uploads WHERE id = :uploadId''', {'uploadId': uploadId});
          if (up.rows.isNotEmpty) {
            final u = up.rows.first;
            await _db.execute('''INSERT INTO message_attachments (message_id, filename, original_filename, file_path, file_size, mime_type, created_at) VALUES (:messageId, :storedFilename, :originalFilename, :filePath, :fileSize, :mimeType, NOW())''', {
              'messageId': messageId,
              'storedFilename': u.colByName('stored_filename'),
              'originalFilename': u.colByName('original_filename'),
              'filePath': u.colByName('file_path'),
              'fileSize': u.colByName('file_size'),
              'mimeType': u.colByName('mime_type'),
            });
          }
        }
        
        if (type == 'voice' && voiceMetadata != null) {
          final uploadId = uploadIds.first;
          final up = await _db.execute('''SELECT id, file_path, file_size FROM file_uploads WHERE id = :uploadId''', {'uploadId': uploadId});
          if (up.rows.isNotEmpty) {
            final u = up.rows.first;
            final filePath = u.colByName('file_path');
            final fileSize = u.colByName('file_size');
            final durationSeconds = voiceMetadata['duration_seconds'] ?? 0;
            final waveformData = voiceMetadata['waveform_data'] ?? '';
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
            await _db.execute('''
              INSERT INTO message_voice_messages (message_id, file_path, duration, waveform_data, file_size, created_at)
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

      await _db.execute(
        'UPDATE conversations SET last_message_at = NOW(), updated_at = NOW() WHERE id = :conversationId',
        {'conversationId': conversationId}
      );

      final msgRes = await _db.execute('''
        SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type, m.reply_to_id, 
               m.is_edited, m.edited_at, m.created_at, m.updated_at, 
               u.username as sender_name, u.avatar_url as sender_avatar,
               mi.client_message_id
        FROM messages m 
        JOIN users u ON m.sender_id = u.id 
        LEFT JOIN message_idempotency mi ON m.id = mi.server_message_id
        WHERE m.id = :messageId
      ''', {'messageId': messageId});
      if (msgRes.rows.isNotEmpty) {
        final built = await _buildMessageFromRow(msgRes.rows.first, _db);
        return {'success': true, 'message': built};
      }
      return {'success': false, 'message': 'Failed to retrieve sent message'};
    }
  }

  Future<void> markMessagesAsRead({required List<String> messageIds, required String userId}) async {
    if (messageIds.isEmpty) return;
    
    // P2 FIX: PERFORMANCE - Use batch insert instead of loop
    final params = <String, dynamic>{'userId': userId};
    final placeholders = [];
    for (int i = 0; i < messageIds.length; i++) {
      final key = 'm$i';
      placeholders.add('(:m$i, :userId, NOW())');
      params[key] = messageIds[i];
    }
    
    final query = '''
      INSERT INTO message_reads (message_id, user_id, read_at) 
      VALUES ${placeholders.join(', ')}
      ON DUPLICATE KEY UPDATE read_at = NOW()
    ''';
    
    await _db.execute(query, params);
  }

  Future<void> markConversationAsRead({required String conversationId, required String userId}) async {
    await _db.execute('''UPDATE conversation_members SET last_read_at = NOW() WHERE conversation_id = :conversationId AND user_id = :userId''', {'conversationId': conversationId, 'userId': userId});
  }

  Future<Map<String, dynamic>> leaveConversation({required String conversationId, required String userId}) async {
    final convRes = await _db.execute('SELECT type FROM conversations WHERE id = :id', {'id': conversationId});
    if (convRes.rows.isEmpty) return {'success': false, 'message': 'Conversation not found'};
    final type = convRes.rows.first.colByName('type')?.toString() ?? 'group';

    // Set history_cleared_at to NOW() so existing messages are hidden for this user.
    // Also set left_at = NOW() if it's a group, or just to mark inactivity.
    await _db.execute(
      'UPDATE conversation_members SET history_cleared_at = NOW(), left_at = NOW() WHERE conversation_id = :conversationId AND user_id = :userId',
      {'conversationId': conversationId, 'userId': userId}
    );

    return {'success': true, 'type': type};
  }

  Future<void> setTypingIndicator({required String conversationId, required String userId, required bool isTyping}) async {
    if (isTyping) {
      await _db.execute('''INSERT INTO typing_events (conversation_id, user_id, is_typing, last_seen_at) VALUES (:conversationId, :userId, TRUE, NOW()) ON DUPLICATE KEY UPDATE is_typing = TRUE, last_seen_at = NOW()''', {'conversationId': conversationId, 'userId': userId});
    } else {
      await _db.execute('''DELETE FROM typing_events WHERE conversation_id = :conversationId AND user_id = :userId''', {'conversationId': conversationId, 'userId': userId});
    }
    // Optimization: Only purge events occasionally (e.g., 5% of calls) to reduce DB load
    if (DateTime.now().millisecond % 20 == 0) {
      await _db.execute('''DELETE FROM typing_events WHERE last_seen_at < DATE_SUB(NOW(), INTERVAL 1 HOUR)''');
    }
  }

  Future<List<Map<String, dynamic>>> getTypingUsers(String conversationId, String userId) async {
    // Check membership first
    final member = await _db.execute('''
      SELECT id FROM conversation_members WHERE conversation_id = :conversationId AND user_id = :userId AND left_at IS NULL
    ''', {'conversationId': conversationId, 'userId': userId});
    if (member.rows.isEmpty) return [];

    final res = await _db.execute('''
      SELECT te.user_id, u.username, te.last_seen_at FROM typing_events te 
      JOIN users u ON te.user_id = u.id 
      WHERE te.conversation_id = :conversationId 
      AND te.user_id != :userId
      AND te.is_typing = TRUE 
      AND te.last_seen_at > DATE_SUB(NOW(), INTERVAL 30 SECOND) 
      ORDER BY te.last_seen_at DESC
    ''', {'conversationId': conversationId, 'userId': userId});
    return res.rows.map<Map<String, dynamic>>((r) => {
      'userId': r.colByName('user_id')?.toString(),
      'username': r.colByName('username'),
      'lastSeenAt': r.colByName('last_seen_at')?.toString()
    }).toList();
  }

  Future<Map<String, dynamic>> createConversation({
    required String creatorId,
    required List<String> participantIds,
    required String type,
    String? name,
    String? avatarUrl,
  }) async {
    final allParticipants = participantIds.toSet().toList();
    if (!allParticipants.contains(creatorId)) {
      allParticipants.add(creatorId);
    }

    if (type == 'direct' && allParticipants.length == 2) {
      final user1Id = allParticipants[0];
      final user2Id = allParticipants[1];
      
      final existing = await _db.execute('''
        SELECT c.id, c.is_archived FROM conversations c 
        JOIN conversation_members cm1 ON c.id = cm1.conversation_id 
        JOIN conversation_members cm2 ON c.id = cm2.conversation_id 
        WHERE c.type = 'direct' 
        AND ((cm1.user_id = :user1Id AND cm2.user_id = :user2Id) 
             OR (cm1.user_id = :user2Id AND cm2.user_id = :user1Id))
        LIMIT 1
      ''', {'user1Id': user1Id, 'user2Id': user2Id});
      
      if (existing.rows.isNotEmpty) {
        final convIdStr = existing.rows.first.colByName('id').toString();
        // If it was archived or someone left, reset it
        await _db.execute(
          'UPDATE conversations SET is_archived = FALSE WHERE id = :id',
          {'id': convIdStr}
        );
        await _db.execute(
          'UPDATE conversation_members SET left_at = NULL WHERE conversation_id = :id',
          {'id': convIdStr}
        );
        
        return {'exists': true, 'id': convIdStr};
      }
    }

    final insert = await _db.execute('''
      INSERT INTO conversations (name, type, avatar_url, created_by, created_at, updated_at, last_message_at) 
      VALUES (:name, :type, :avatarUrl, :createdBy, NOW(), NOW(), NOW())
    ''', {
      'name': type == 'direct' ? null : name, 
      'type': type, 
      'avatarUrl': avatarUrl,
      'createdBy': creatorId
    });
    
    final conversationId = insert.lastInsertID.toInt();

    for (final userId in allParticipants) {
      await _db.execute('''
        INSERT INTO conversation_members (conversation_id, user_id, joined_at) 
        VALUES (:conversationId, :userId, NOW())
      ''', {'conversationId': conversationId, 'userId': userId});
    }

    // P1 FIX: Invalidate presence caches for all participants so they see each other's status immediately
    WebSocketServer.invalidatePresenceCache(allParticipants);

    return {'exists': false, 'id': conversationId.toString()};
  }

  // Helper (Internal)
  Future<Map<String, dynamic>> _buildMessageFromRow(dynamic row, dynamic tx) async {
    final messageId = row.colByName('id')?.toString();
    
    // 1. Fetch Attachments
    final attRes = await tx.execute('''SELECT id, filename, original_filename, file_path, file_size, mime_type, thumbnail_path, created_at FROM message_attachments WHERE message_id = :messageId''', {'messageId': messageId});
    final attachments = attRes.rows.map((r) {
      return {
        'id': r.colByName('id')?.toString(),
        'type': r.colByName('mime_type')?.toString().startsWith('image/') == true ? 'image' : 'file',
        'filename': r.colByName('original_filename') ?? r.colByName('filename'),
        'media_url': '/media/${r.colByName('filename')}',
      };
    }).toList();

    // 2. Fetch Voice Message
    Map<String, dynamic>? voiceMessage;
    final vmRes = await tx.execute('''SELECT id, file_path, duration, waveform_data, file_size FROM message_voice_messages WHERE message_id = :messageId''', {'messageId': messageId});
    if (vmRes.rows.isNotEmpty) {
      final vm = vmRes.rows.first;
      
      // FIXED: Parse waveform_data if it's a string representing JSON
      dynamic waveform = vm.colByName('waveform_data');
      if (waveform is String && (waveform.startsWith('[') || waveform.startsWith('{'))) {
        try {
          waveform = jsonDecode(waveform);
        } catch (_) {
          waveform = [];
        }
      } else {
        waveform ??= [];
      }

      voiceMessage = {
        'fileId': vm.colByName('id')?.toString(),
        'duration': vm.colByName('duration')?.toString(),
        'url': '/media/${vm.colByName('file_path')?.toString().split('/').last}', // Legacy
        'mediaUrl': '/media/${vm.colByName('file_path')?.toString().split('/').last}', // Standard
        'waveform': waveform is List ? waveform : [],
      };
    }

    String? clientMessageId;
    try {
      clientMessageId = row.colByName('client_message_id')?.toString();
    } catch (_) {
      // Column might not be selected in some specific queries
    }

    return {
      'id': messageId,
      'clientMessageId': clientMessageId,
      'conversationId': row.colByName('conversation_id')?.toString(),
      'senderId': row.colByName('sender_id')?.toString(),
      'senderName': row.colByName('sender_name'),
      'senderAvatar': _normalizePhoto(row.colByName('sender_avatar')),
      'content': row.colByName('content'),
      'type': row.colByName('type'),
      'attachments': attachments,
      'voiceMessage': voiceMessage,
      'isEdited': row.colByName('is_edited') == '1',
      'createdAt': row.colByName('created_at')?.toString().replaceAll(' ', 'T'),
    };
  }

  String? _normalizePhoto(String? photo) {
    if (photo == null || photo.trim().isEmpty) return null;
    final clean = photo.replaceAll(RegExp(r'\s+'), '');
    
    if (clean.startsWith('data:image')) return clean;
    
    if (clean.length > 100) {
      final isPng = clean.startsWith('iVBORw0KGgo');
      final isJpeg = clean.startsWith('/9j/');
      final mimeType = isPng ? 'image/png' : isJpeg ? 'image/jpeg' : 'image/jpeg';
      return 'data:$mimeType;base64,$clean';
    }
    
    if (clean.startsWith('http')) return clean;
    
    // It's a filename or /media/ path
    final relativePath = clean.replaceAll(RegExp(r'^[/\\]+media[/\\]+'), '').replaceAll(RegExp(r'^[/\\]+'), '');
    return '/media/$relativePath';
  }

  /// P2-1 FIX: Cleanup job for orphaned file uploads.
  /// Deletes uploads older than 24h that were never attached to a message.
  Future<int> cleanupOrphanedUploads() async {
    try {
      final res = await _db.execute('''
        DELETE FROM file_uploads 
        WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY)
        AND file_path NOT IN (SELECT file_path FROM message_attachments)
        AND file_path NOT IN (SELECT file_path FROM message_voice_messages)
      ''');
      print('[ChatRepository] Cleaned up ${res.affectedRows} orphaned uploads.');
      return res.affectedRows.toInt();
    } catch (e) {
      print('[ChatRepository] Error during uploads cleanup: $e');
      return 0;
    }
  }
}
