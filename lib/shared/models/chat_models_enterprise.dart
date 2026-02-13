import 'dart:convert';

enum ChatMessageType {
  text,
  image,
  file,
  audio,
  system,
  typing,
  readReceipt;

  String get name => toString().split('.').last;
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  String get name => toString().split('.').last;
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final ChatMessageType type;
  final String? mediaUrl;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    this.mediaUrl,
    this.metadata = const {},
    required this.timestamp,
    required this.status,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      content: json['content'] ?? '',
      type: ChatMessageType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => ChatMessageType.text,
      ),
      mediaUrl: json['mediaUrl'],
      metadata: json['metadata'] ?? {},
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      status: MessageStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'isRead': isRead,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    ChatMessageType? type,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
    );
  }
}

class ChatAttachment {
  final String id;
  final String messageId;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String url;
  final DateTime uploadedAt;

  ChatAttachment({
    required this.id,
    required this.messageId,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.url,
    required this.uploadedAt,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] ?? '',
      messageId: json['messageId'] ?? '',
      fileName: json['fileName'] ?? '',
      mimeType: json['mimeType'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      url: json['url'] ?? '',
      uploadedAt: DateTime.parse(json['uploadedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'url': url,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

class VoiceMessage {
  final String id;
  final String messageId;
  final String audioUrl;
  final Duration duration;
  final DateTime recordedAt;
  final bool isPlayed;

  VoiceMessage({
    required this.id,
    required this.messageId,
    required this.audioUrl,
    required this.duration,
    required this.recordedAt,
    this.isPlayed = false,
  });

  factory VoiceMessage.fromJson(Map<String, dynamic> json) {
    return VoiceMessage(
      id: json['id'] ?? '',
      messageId: json['messageId'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      duration: Duration(seconds: json['duration'] ?? 0),
      recordedAt: DateTime.parse(json['recordedAt'] ?? DateTime.now().toIso8601String()),
      isPlayed: json['isPlayed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'audioUrl': audioUrl,
      'duration': duration.inSeconds,
      'recordedAt': recordedAt.toIso8601String(),
      'isPlayed': isPlayed,
    };
  }
}
