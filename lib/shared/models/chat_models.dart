class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? content;
  final String type;
  final DateTime createdAt;
  final bool isFromMe;
  final String? replyToId;
  final List<ChatAttachment> attachments;
  final VoiceMessage? voiceMessage;
  final List<String> reactions;
  final bool isEdited;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.content,
    required this.type,
    required this.createdAt,
    required this.isFromMe,
    this.replyToId,
    this.attachments = const [],
    this.voiceMessage,
    this.reactions = const [],
    this.isEdited = false,
    this.isRead = false,
  });

  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasVoiceMessage => voiceMessage != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatar: json['senderAvatar'] as String?,
      content: json['content'] as String?,
      type: json['type'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isFromMe: json['isFromMe'] as bool,
      replyToId: json['replyToId'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      voiceMessage: json['voiceMessage'] != null 
          ? VoiceMessage.fromJson(json['voiceMessage'] as Map<String, dynamic>)
          : null,
      reactions: (json['reactions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      isEdited: json['isEdited'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'isFromMe': isFromMe,
      'replyToId': replyToId,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'voiceMessage': voiceMessage?.toJson(),
      'reactions': reactions,
      'isEdited': isEdited,
      'isRead': isRead,
    };
  }
}

class ChatAttachment {
  final String id;
  final String filename;
  final String originalFilename;
  final String mimeType;
  final int size;
  final String url;
  final String displaySize;
  final String? thumbnailUrl;

  ChatAttachment({
    required this.id,
    required this.filename,
    required this.originalFilename,
    required this.mimeType,
    required this.size,
    required this.url,
    required this.displaySize,
    this.thumbnailUrl,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isDocument => !isImage && !isVideo && !isAudio;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] as String,
      filename: json['filename'] as String,
      originalFilename: json['originalFilename'] as String,
      mimeType: json['mimeType'] as String,
      size: json['size'] as int,
      url: json['url'] as String,
      displaySize: json['displaySize'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'originalFilename': originalFilename,
      'mimeType': mimeType,
      'size': size,
      'url': url,
      'displaySize': displaySize,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

class VoiceMessage {
  final String fileId;
  final String duration;
  final List<double> waveform;
  final String? transcription;

  VoiceMessage({
    required this.fileId,
    required this.duration,
    required this.waveform,
    this.transcription,
  });

  factory VoiceMessage.fromJson(Map<String, dynamic> json) {
    return VoiceMessage(
      fileId: json['fileId'] as String,
      duration: json['duration'] as String,
      waveform: (json['waveform'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      transcription: json['transcription'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'duration': duration,
      'waveform': waveform,
      'transcription': transcription,
    };
  }
}