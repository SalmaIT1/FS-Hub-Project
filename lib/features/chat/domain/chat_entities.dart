import 'message_state_machine.dart';

/// Represents a single message in a conversation
/// 
/// Invariants:
/// - `id` is always server-assigned (never client-generated)
/// - `clientMessageId` is optional, used by backend for idempotency
/// - `state` reflects backend acknowledgment, not UI optimism
/// - All timestamps are server-canonical
/// - `attachments` are only present if upload succeeded
class ChatMessage {
  /// Server-assigned ID (UTC timestamp or serial)
  final String id;

  /// Client-provided idempotency key (optional)
  final String? clientMessageId;

  /// Conversation this message belongs to
  final String conversationId;

  /// Sender user ID
  final String senderId;

  /// Sender display name (from server)
  final String? senderName;

  /// Sender avatar URL (from server)
  final String? senderAvatar;

  /// Message content
  final String content;

  /// Message type: text, file, image, audio, system
  final String type;

  /// ID of parent message (for replies)
  final String? replyToId;

  /// Current lifecycle state
  final MessageState state;

  /// Server-canonical created timestamp
  final DateTime createdAt;

  /// Server-canonical updated timestamp
  final DateTime updatedAt;

  /// Message was edited (server flag)
  final bool isEdited;

  /// When message was edited (server timestamp)
  final DateTime? editedAt;

  /// Attachment metadata (only if type == 'file' or 'image')
  final List<AttachmentEntity> attachments;

  /// Voice note metadata (only if type == 'audio')
  final VoiceNoteEntity? voiceNote;

  /// Per-recipient delivery status
  final List<MessageDeliveryStatus> deliveryStatus;

  /// Reactions/emojis (if any)
  final Map<String, List<String>> reactions;

  /// Whether sender has read this message (in their own thread)
  final bool isReadBySender;

  /// Retry attempt count (UI state only, not from server)
  final int retryCount;

  /// Upload progress (0-1, for UI only)
  final double uploadProgress;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.clientMessageId,
    this.senderName,
    this.senderAvatar,
    this.replyToId,
    this.isEdited = false,
    this.editedAt,
    this.attachments = const [],
    this.voiceNote,
    this.deliveryStatus = const [],
    this.reactions = const {},
    this.isReadBySender = false,
    this.retryCount = 0,
    this.uploadProgress = 0.0,
  });

  /// Factory: parse from REST/WebSocket response
  factory ChatMessage.fromServerJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      clientMessageId: json['clientMessageId']?.toString(),
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      state: MessageState.sent, // Server only sends persisted messages
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      senderName: json['senderName'],
      senderAvatar: json['senderAvatar'],
      replyToId: json['replyToId']?.toString(),
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] != null ? _parseDateTime(json['editedAt']) : null,
      attachments: (json['attachments'] as List?)
          ?.map((a) => AttachmentEntity.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
      voiceNote: json['voiceMessage'] != null 
          ? VoiceNoteEntity.fromJson(json['voiceMessage'] as Map<String, dynamic>) 
          : null,
      isReadBySender: json['isRead'] ?? false,
    );
  }

  /// Convert to JSON for display/storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'clientMessageId': clientMessageId,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'content': content,
    'type': type,
    'replyToId': replyToId,
    'state': state.toString(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isEdited': isEdited,
    'editedAt': editedAt?.toIso8601String(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'voiceNote': voiceNote?.toJson(),
    'deliveryStatus': deliveryStatus.map((d) => d.toJson()).toList(),
    'reactions': reactions,
    'isReadBySender': isReadBySender,
    'retryCount': retryCount,
    'uploadProgress': uploadProgress,
  };

  /// Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? clientMessageId,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    String? type,
    String? replyToId,
    MessageState? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    DateTime? editedAt,
    List<AttachmentEntity>? attachments,
    VoiceNoteEntity? voiceNote,
    List<MessageDeliveryStatus>? deliveryStatus,
    Map<String, List<String>>? reactions,
    bool? isReadBySender,
    int? retryCount,
    double? uploadProgress,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      replyToId: replyToId ?? this.replyToId,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      attachments: attachments ?? this.attachments,
      voiceNote: voiceNote ?? this.voiceNote,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      reactions: reactions ?? this.reactions,
      isReadBySender: isReadBySender ?? this.isReadBySender,
      retryCount: retryCount ?? this.retryCount,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Attachment metadata
class AttachmentEntity {
  final String id;
  final String conversationId;
  final String messageId;
  final String filename;
  final String mimeType;
  final int size;
  final String uploadUrl;
  final DateTime uploadedAt;

  AttachmentEntity({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.uploadUrl,
    required this.uploadedAt,
  });

  factory AttachmentEntity.fromJson(Map<String, dynamic> json) => AttachmentEntity(
    id: json['id']?.toString() ?? '',
    conversationId: json['conversationId']?.toString() ?? '',
    messageId: json['messageId']?.toString() ?? '',
    filename: json['filename'] ?? '',
    mimeType: json['mimeType'] ?? json['mime_type'] ?? json['mime'] ?? 'application/octet-stream',
    size: json['size'] ?? json['file_size'] ?? json['fileSize'] ?? 0,
    uploadUrl: json['media_url'] ?? json['mediaUrl'] ?? json['uploadUrl'] ?? json['upload_url'] ?? json['url'] ?? json['file_path'] ?? '',
    uploadedAt: _parseDateTime(json['uploadedAt'] ?? json['uploaded_at'] ?? json['createdAt'] ?? json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'messageId': messageId,
    'filename': filename,
    'mimeType': mimeType,
    'size': size,
    'uploadUrl': uploadUrl,
    'uploadedAt': uploadedAt.toIso8601String(),
  };
}

/// Voice note metadata
class VoiceNoteEntity {
  final String id;
  final String uploadUrl;
  final int durationMs;
  final DateTime recordedAt;
  final String waveformData; // base64 or hex encoded waveform samples

  VoiceNoteEntity({
    required this.id,
    required this.uploadUrl,
    required this.durationMs,
    required this.recordedAt,
    required this.waveformData,
  });

  factory VoiceNoteEntity.fromJson(Map<String, dynamic> json) => VoiceNoteEntity(
    id: json['id']?.toString() ?? json['fileId']?.toString() ?? '',
    uploadUrl: json['media_url'] ?? json['mediaUrl'] ?? json['uploadUrl'] ?? json['upload_url'] ?? json['url'] ?? json['file_path'] ?? '',
    durationMs: (() {
      final raw = json['durationMs'] ?? json['duration'] ?? json['duration_seconds'] ?? json['durationSeconds'];
      if (raw == null) return 0;
      int val = 0;
      if (raw is num) val = raw.toInt();
      else val = int.tryParse(raw.toString()) ?? 0;
      // If value looks like seconds (less than 1000), convert to ms
      if (val > 0 && val < 1000) return val * 1000;
      return val;
    })(),
    recordedAt: _parseDateTime(json['recordedAt'] ?? json['recorded_at'] ?? json['createdAt'] ?? json['created_at']),
    waveformData: (json['waveformData'] ?? json['waveform'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'uploadUrl': uploadUrl,
    'durationMs': durationMs,
    'recordedAt': recordedAt.toIso8601String(),
    'waveformData': waveformData,
  };
}

/// Conversation metadata
class ConversationEntity {
  final String id;
  final String name;
  final String type; // 'direct' or 'group'
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final String? lastMessageSenderName;
  final List<String> memberIds;
  final int unreadCount;
  final bool isArchived;
  final DateTime? archivedAt;
  final List<String> typingUserIds; // Real-time typing indicators

  ConversationEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.lastMessageAt,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.memberIds = const [],
    this.unreadCount = 0,
    this.isArchived = false,
    this.archivedAt,
    this.typingUserIds = const [],
  });

  factory ConversationEntity.fromServerJson(Map<String, dynamic> json) {
    return ConversationEntity(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'direct',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      avatarUrl: json['avatarUrl'],
      lastMessageAt: json['lastMessageAt'] != null ? _parseDateTime(json['lastMessageAt']) : null,
      lastMessage: json['lastMessage'],
      lastMessageSenderId: json['lastMessageSenderId']?.toString(),
      lastMessageSenderName: json['lastMessageSenderName'],
      memberIds: List<String>.from(json['memberIds'] as List? ?? []),
      unreadCount: json['unreadCount'] ?? 0,
      isArchived: json['isArchived'] ?? false,
      archivedAt: json['archivedAt'] != null ? _parseDateTime(json['archivedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'avatarUrl': avatarUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastMessageAt': lastMessageAt?.toIso8601String(),
    'lastMessage': lastMessage,
    'lastMessageSenderId': lastMessageSenderId,
    'lastMessageSenderName': lastMessageSenderName,
    'memberIds': memberIds,
    'unreadCount': unreadCount,
    'isArchived': isArchived,
    'archivedAt': archivedAt?.toIso8601String(),
    'typingUserIds': typingUserIds,
  };

  ConversationEntity copyWith({
    String? id,
    String? name,
    String? type,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    String? lastMessage,
    String? lastMessageSenderId,
    String? lastMessageSenderName,
    List<String>? memberIds,
    int? unreadCount,
    bool? isArchived,
    DateTime? archivedAt,
    List<String>? typingUserIds,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
      memberIds: memberIds ?? this.memberIds,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      typingUserIds: typingUserIds ?? this.typingUserIds,
    );
  }
}

/// Helper for parsing server timestamps
DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}
