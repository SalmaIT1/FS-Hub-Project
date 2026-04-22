import 'chat_attachment_model.dart';
import 'voice_message_model.dart';

class ChatMessageModel {
  final String id;
  final String? clientMessageId;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String content;
  final String type;
  final String? replyToId;
  final bool isEdited;
  final String? editedAt;
  final String? createdAt;
  final String? updatedAt;
  final List<ChatAttachmentModel> attachments;
  final VoiceMessageModel? voiceMessage;
  final List<dynamic> reactions;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    this.clientMessageId,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    this.replyToId,
    required this.isEdited,
    this.editedAt,
    this.createdAt,
    this.updatedAt,
    required this.attachments,
    this.voiceMessage,
    required this.reactions,
    required this.isRead,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientMessageId': clientMessageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName ?? 'Unknown',
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type,
      'replyToId': replyToId,
      'isEdited': isEdited,
      'editedAt': editedAt,
      'createdAt': createdAt?.replaceAll(' ', 'T') ?? DateTime.now().toIso8601String(),
      'isFromMe': false, // Frontend datasource will overwrite this if needed
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'voiceMessage': voiceMessage?.toJson(),
      'reactions': reactions,
      'isRead': isRead,
    };
  }
}
