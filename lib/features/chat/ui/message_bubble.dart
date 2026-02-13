import 'package:flutter/material.dart';
import '../../../chat/domain/chat_entities.dart';
import '../../../chat/domain/message_state_machine.dart';
import 'media_components.dart';

/// Message bubble widget
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFromCurrentUser;
  final bool isGroupChat;
  final VoidCallback? onRetap;
  final VoidCallback? onRetry;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isFromCurrentUser,
    this.isGroupChat = false,
    this.onRetap,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromCurrentUser && isGroupChat)
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: message.senderAvatar != null ? NetworkImage(message.senderAvatar!) : null,
                child: message.senderAvatar == null ? Icon(Icons.person, size: 16) : null,
              ),
            ),
          Flexible(child: _buildMessageContent(context)),
          if (isFromCurrentUser)
            Padding(padding: EdgeInsets.only(left: 8.0), child: _buildDeliveryIcon()),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    return GestureDetector(
      onTap: onRetap,
      child: Container(
        decoration: BoxDecoration(
          color: isFromCurrentUser ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromCurrentUser && isGroupChat && message.senderName != null)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(message.senderName!, style: Theme.of(context).textTheme.labelSmall),
              ),
            if (message.type == 'text')
              Text(message.content, style: Theme.of(context).textTheme.bodyMedium)
            else if (message.type == 'mixed' || message.type == 'image' || message.type == 'file')
              _buildAttachmentPreview(context)
            else if (message.type == 'audio' || message.type == 'voice')
              _buildVoiceNotePreview(context),
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatTime(message.createdAt), style: Theme.of(context).textTheme.labelSmall),
                  if (message.isEdited)
                    Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text('(edited)', style: Theme.of(context).textTheme.labelSmall),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(BuildContext context) {
    if (message.attachments.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(message.content, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ...message.attachments.map((att) => _buildAttachmentTile(context, att)).toList(),
      ],
    );
  }

  Widget _buildAttachmentTile(BuildContext context, AttachmentEntity attachment) {
    final mimeType = attachment.mimeType;
    if (mimeType.startsWith('image/')) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: InlineImageBubble(attachment: attachment),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: FileAttachmentBubble(attachment: attachment),
    );
  }

  Widget _buildVoiceNotePreview(BuildContext context) {
    if (message.voiceNote == null) return SizedBox.shrink();
    return VoiceNoteBubble(voice: message.voiceNote!);
  }

  Widget _buildDeliveryIcon() {
    switch (message.state) {
      case MessageState.draft:
      case MessageState.queued:
        return Icon(Icons.schedule, size: 16, color: Colors.orange);
      case MessageState.uploading:
      case MessageState.sending:
        return SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
      case MessageState.sent:
        return Icon(Icons.done, size: 16, color: Colors.grey);
      case MessageState.delivered:
        return Icon(Icons.done_all, size: 16, color: Colors.blue);
      case MessageState.read:
        return Icon(Icons.done_all, size: 16, color: Colors.blueAccent);
      case MessageState.failed:
        return GestureDetector(onTap: onRetry, child: Icon(Icons.error, size: 16, color: Colors.red));
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }
 
}


