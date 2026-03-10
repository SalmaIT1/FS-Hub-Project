import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';
import 'package:fs_hub/shared/models/chat_models.dart';
import 'media_components.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/core/utils/url_utils.dart';
import 'package:fs_hub/shared/widgets/authenticated_image.dart';
import 'avatar_helper.dart';

/// Message bubble widget
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFromCurrentUser;
  final bool isGroupChat;
  final VoidCallback? onRetap;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.isGroupChat = false,
    this.onRetap,
    this.onRetry,
  });

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
              padding: const EdgeInsets.only(right: 8.0),
              child: AvatarHelper.buildAvatar(
                message.senderAvatar,
                size: 32,
                initials: message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : null,
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
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Bubble colors
    final bubbleColor = isFromCurrentUser
        ? (isDark ? theme.colorScheme.primary.withOpacity(0.2) : Colors.blue[100])
        : (isDark ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5) : Colors.grey[200]);
    
    // Text colors
    final textColor = isFromCurrentUser
        ? (isDark ? theme.colorScheme.primary : Colors.black87)
        : (isDark ? theme.colorScheme.onSurface : Colors.black87);

    return GestureDetector(
      onTap: onRetap,
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(
            color: isFromCurrentUser 
                ? theme.colorScheme.primary.withOpacity(0.2)
                : theme.colorScheme.onSurface.withOpacity(0.1),
            width: 0.5,
          ) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromCurrentUser && isGroupChat && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName!, 
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? theme.colorScheme.secondary : null,
                  ),
                ),
              ),
            if (message.type == 'text')
              Text(
                message.content ?? '', 
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? theme.colorScheme.onSurface : null,
                ),
              )
            else if (message.type == 'mixed' || message.type == 'image' || message.type == 'file')
              _buildAttachmentPreview(context)
            else if (message.type == 'audio' || message.type == 'voice')
              _buildVoiceNotePreview(context),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDateTime(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey[600],
                    ),
                  ),
                  if (message.isEdited)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '· ${settings.translate('edited')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.grey[600],
                        ),
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

  Widget _buildAttachmentPreview(BuildContext context) {
    if (message.attachments.isEmpty) return SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content != null && message.content!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              message.content!, 
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? theme.colorScheme.onSurface : null,
              ),
            ),
          ),
        ...message.attachments.map((att) => _buildAttachmentTile(context, att)).toList(),
      ],
    );
  }

  Widget _buildAttachmentTile(BuildContext context, ChatAttachment attachment) {
    final mimeType = attachment.mimeType;
    if (mimeType.startsWith('image/')) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: InlineImageBubble(attachment: AttachmentEntity(
          id: attachment.id,
          uploadUrl: attachment.url,
          thumbnailUrl: attachment.thumbnailUrl,
          fileName: attachment.filename,
          fileSize: attachment.size,
          mimeType: attachment.mimeType,
        )),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: FileAttachmentBubble(attachment: AttachmentEntity(
        id: attachment.id,
        uploadUrl: attachment.url,
        thumbnailUrl: attachment.thumbnailUrl,
        fileName: attachment.filename,
        fileSize: attachment.size,
        mimeType: attachment.mimeType,
      )),
    );
  }

  Widget _buildVoiceNotePreview(BuildContext context) {
    if (message.voiceMessage == null && !message.attachments.any((a) => a.isAudio)) {
      return SizedBox.shrink();
    }
    
    final vm = message.voiceMessage;
    
    // Find matching attachment to get the URL
    final voiceAttachment = message.attachments.firstWhere(
      (a) => (vm != null && a.id == vm.fileId) || a.mimeType.startsWith('audio/'),
      orElse: () => message.attachments.isNotEmpty ? message.attachments.first : (ChatAttachment(
        id: 'unknown',
        filename: 'audio.aac',
        originalFilename: 'audio.aac',
        mimeType: 'audio/aac',
        size: 0,
        url: '',
        displaySize: '0 B'
      )),
    );
    
    final url = UrlUtils.ensureAbsoluteUrl(voiceAttachment.url);

    return VoiceNoteBubble(
      voice: VoiceNoteEntity(
        id: vm?.fileId ?? voiceAttachment.id,
        url: url,
        durationMs: vm != null 
            ? (int.tryParse(vm.duration.replaceAll(RegExp('[^0-9]'), '')) ?? 0)
            : (voiceAttachment.size > 0 ? voiceAttachment.size * 10 : 5000), 
        waveform: vm?.waveform ?? const [],
        transcription: vm?.transcription,
      ),
      isSentByMe: isFromCurrentUser,
    );
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

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return time;
    
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final month = months[dt.month - 1];
    final day = dt.day;
    if (dt.year == now.year) return '$month $day · $time';
    return '$month $day ${dt.year} · $time';
  }

  // Keep for backward compat
  String _formatTime(DateTime dt) => _formatDateTime(dt);
 
}





