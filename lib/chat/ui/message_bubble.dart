import 'package:flutter/material.dart';
import '../domain/chat_entities.dart';
import '../domain/message_state_machine.dart';

/// Message bubble widget
/// 
/// Renders:
/// - Text content
/// - Delivery state icon (sending, sent, delivered, read, failed)
/// - Timestamp
/// - Sender avatar (if group chat)
/// - Retry button (if failed)
/// - Reply context (if replying)
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
      padding: EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 4.0,
      ),
      child: Row(
        mainAxisAlignment: isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromCurrentUser && isGroupChat)
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: message.senderAvatar != null
                    ? NetworkImage(message.senderAvatar!)
                    : null,
                child: message.senderAvatar == null
                    ? Icon(Icons.person, size: 16)
                    : null,
              ),
            ),
          Flexible(
            child: _buildMessageContent(context),
          ),
          if (isFromCurrentUser)
            Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: _buildDeliveryIcon(),
            ),
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
                child: Text(
                  message.senderName!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            if (message.type == 'text')
              Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (message.type == 'image' || message.type == 'file')
              _buildAttachmentPreview()
            else if (message.type == 'audio')
              _buildVoiceNotePreview(),
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (message.isEdited)
                    Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        '(edited)',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    if (message.attachments.isEmpty) return SizedBox.shrink();
    final att = message.attachments.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.type == 'image')
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Image.network(
              att.uploadUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.broken_image),
            ),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.attachment),
            title: Text(att.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${(att.size / 1024).toStringAsFixed(1)} KB'),
          ),
      ],
    );
  }

  Widget _buildVoiceNotePreview() {
    if (message.voiceNote == null) return SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_fill),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Voice message'),
              Text(_formatDuration(message.voiceNote!.durationMs)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryIcon() {
    switch (message.state) {
      case MessageState.draft:
      case MessageState.queued:
        return Icon(Icons.schedule, size: 16, color: Colors.orange);
      case MessageState.uploading:
      case MessageState.sending:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case MessageState.sent:
        return Icon(Icons.done, size: 16, color: Colors.grey);
      case MessageState.delivered:
        return Icon(Icons.done_all, size: 16, color: Colors.blue);
      case MessageState.read:
        return Icon(Icons.done_all, size: 16, color: Colors.blueAccent);
      case MessageState.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Icon(Icons.error, size: 16, color: Colors.red),
        );
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }

  String _formatDuration(int ms) {
    final secs = ms ~/ 1000;
    return '$secs"';
  }
}
