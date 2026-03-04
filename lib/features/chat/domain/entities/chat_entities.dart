import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fs_hub/shared/models/chat_models.dart';

// Re-export for backwards compatibility
export 'package:fs_hub/shared/models/chat_models.dart';

/// Attachment state enum
enum AttachmentState {
  selecting,
  uploading,
  uploaded,
  failed,
  ready,
}

class ConversationEntity {
  final String id;
  final String name;
  final String? avatar;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isGroup;
  final List<String> participantIds;
  final String? clientMessageId;
  final String type;
  final bool isOnline;
  final List<String> typingUserIds;
  final bool isArchived;
  final bool isPinned;
  final bool isMuted;

  ConversationEntity({
    required this.id,
    required this.name,
    this.avatar,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isGroup = false,
    this.participantIds = const [],
    this.clientMessageId,
    this.type = 'direct',
    this.isOnline = true,
    this.typingUserIds = const [],
    this.isArchived = false,
    this.isPinned = false,
    this.isMuted = false,
  });

  // Alias for avatar
  String? get avatarUrl => avatar;

  factory ConversationEntity.fromJson(Map<String, dynamic> json) {
    return ConversationEntity(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? json['participantName'] as String? ?? 'Unknown',
      avatar: json['avatarUrl'] as String? ?? json['avatar'] as String? ?? json['participantAvatar'] as String?,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt: json['lastMessageAt'] != null 
          ? DateTime.parse(json['lastMessageAt'] as String)
          : DateTime.now(),
      unreadCount: json['unreadCount'] as int? ?? 0,
      isGroup: json['isGroup'] as bool? ?? false,
      participantIds: (json['participantIds'] as List<dynamic>?)
          ?.map<String>((e) => e.toString())
          .toList() ?? [],
      clientMessageId: json['clientMessageId'] as String?,
      type: json['type'] as String? ?? (json['isGroup'] == true ? 'group' : 'direct'),
      isOnline: json['isOnline'] as bool? ?? true,
      typingUserIds: (json['typingUserIds'] as List<dynamic>?)
          ?.map<String>((e) => e.toString())
          .toList() ?? [],
      isArchived: json['isArchived'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'unreadCount': unreadCount,
      'isGroup': isGroup,
      'participantIds': participantIds,
      'clientMessageId': clientMessageId,
      'type': type,
      'isOnline': isOnline,
      'typingUserIds': typingUserIds,
      'isArchived': isArchived,
      'isPinned': isPinned,
      'isMuted': isMuted,
    };
  }

  ConversationEntity copyWith({
    String? id,
    String? name,
    String? avatar,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isGroup,
    List<String>? participantIds,
    String? clientMessageId,
    String? type,
    bool? isOnline,
    List<String>? typingUserIds,
    bool? isArchived,
    bool? isPinned,
    bool? isMuted,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      participantIds: participantIds ?? this.participantIds,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      type: type ?? this.type,
      isOnline: isOnline ?? this.isOnline,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

/// Attachment entity for messages
class AttachmentEntity {
  final String id;
  final String uploadUrl;
  final String? thumbnailUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String? localPath;
  final double? uploadProgress;
  final String? uploadId;
  final AttachmentState state;

  AttachmentEntity({
    required this.id,
    required this.uploadUrl,
    this.thumbnailUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.localPath,
    this.uploadProgress,
    this.uploadId,
    this.state = AttachmentState.ready,
  });

  // Aliases for compatibility
  String get filename => fileName;
  int get size => fileSize;
  String get url => uploadUrl;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isDocument => !isImage && !isVideo && !isAudio;

  factory AttachmentEntity.fromJson(Map<String, dynamic> json) {
    return AttachmentEntity(
      id: json['id']?.toString() ?? '',
      uploadUrl: json['url'] as String? ?? json['uploadUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileName: json['fileName'] as String? ?? json['filename'] as String? ?? 'Unknown',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      localPath: json['localPath'] as String?,
      uploadProgress: json['uploadProgress'] as double?,
      uploadId: json['uploadId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uploadUrl': uploadUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'localPath': localPath,
      'uploadProgress': uploadProgress,
      'uploadId': uploadId,
    };
  }
}

/// Voice note entity for voice messages
class VoiceNoteEntity {
  final String id;
  final String url;
  final int durationMs;
  final List<double> waveform;
  final String? transcription;
  final String? waveformData;
  final String? uploadUrl;
  final DateTime? recordedAt;

  VoiceNoteEntity({
    required this.id,
    required this.url,
    required this.durationMs,
    this.waveform = const [],
    this.transcription,
    this.waveformData,
    this.uploadUrl,
    this.recordedAt,
  });

  String get durationFormatted {
    final seconds = durationMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  factory VoiceNoteEntity.fromJson(Map<String, dynamic> json) {
    return VoiceNoteEntity(
      id: json['id']?.toString() ?? '',
      url: json['url'] as String? ?? '',
      durationMs: json['durationMs'] as int? ?? json['duration_ms'] as int? ?? 0,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? [],
      transcription: json['transcription'] as String?,
      waveformData: json['waveformData'] as String?,
      uploadUrl: json['uploadUrl'] as String? ?? json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'durationMs': durationMs,
      'waveform': waveform,
      'transcription': transcription,
      'waveformData': waveformData,
      'uploadUrl': uploadUrl,
    };
  }
}

/// Attachment manager for handling attachments in chat
class AttachmentManager extends ChangeNotifier {
  final List<AttachmentEntity> _attachments = [];
  bool _isUploading = false;

  List<AttachmentEntity> get attachments => List.unmodifiable(_attachments);
  bool get isUploading => _isUploading;
  bool get hasAttachments => _attachments.isNotEmpty;
  
  // Stream controller for reactive updates
  final _attachmentsController = StreamController<List<AttachmentEntity>>.broadcast();
  Stream<List<AttachmentEntity>> get attachmentsStream => _attachmentsController.stream;

  void addAttachment(AttachmentEntity attachment) {
    _attachments.add(attachment);
    _attachmentsController.add(List.unmodifiable(_attachments));
    notifyListeners();
  }

  void addVoiceRecording(AttachmentEntity attachment) {
    _attachments.add(attachment);
    _attachmentsController.add(List.unmodifiable(_attachments));
    notifyListeners();
  }

  void removeAttachment(String id) {
    _attachments.removeWhere((a) => a.id == id);
    _attachmentsController.add(List.unmodifiable(_attachments));
    notifyListeners();
  }

  void retryUpload(String id) {
    // Mark attachment for retry
    final index = _attachments.indexWhere((a) => a.id == id);
    if (index >= 0) {
      notifyListeners();
    }
  }

  void updateAttachmentProgress(String id, double progress) {
    final index = _attachments.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _attachments[index] = AttachmentEntity(
        id: _attachments[index].id,
        uploadUrl: _attachments[index].uploadUrl,
        thumbnailUrl: _attachments[index].thumbnailUrl,
        fileName: _attachments[index].fileName,
        fileSize: _attachments[index].fileSize,
        mimeType: _attachments[index].mimeType,
        localPath: _attachments[index].localPath,
        uploadProgress: progress,
        uploadId: _attachments[index].uploadId,
      );
      _attachmentsController.add(List.unmodifiable(_attachments));
      notifyListeners();
    }
  }

  void setUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  void clear() {
    _attachments.clear();
    _isUploading = false;
    _attachmentsController.add([]);
    notifyListeners();
  }

  // Stub methods for compatibility
  Future<List<AttachmentEntity>> selectImages({bool fromCamera = false}) async {
    // This is a stub - actual implementation would use image_picker
    return [];
  }

  Future<List<AttachmentEntity>> selectFiles() async {
    // This is a stub - actual implementation would use file_picker
    return [];
  }

  Future<Map<String, dynamic>> uploadAllAttachments() async {
    // Return upload IDs with optional voice metadata
    final uploadIds = _attachments.map((a) => a.id).toList();
    return {
      'uploadIds': uploadIds,
      'voiceMetadata': null,
    };
  }

  Future<void> clearAllAttachments() async {
    clear();
  }

  @override
  void dispose() {
    _attachmentsController.close();
    super.dispose();
  }
}
