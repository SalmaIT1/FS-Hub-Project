import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_models.dart';
import '../../theme/app_theme.dart';

class GlassMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;
  final bool showTimestamp;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onReaction;
  final VoidCallback? onPlayVoice;

  const GlassMessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.showTimestamp = true,
    this.onTap,
    this.onLongPress,
    this.onReply,
    this.onReaction,
    this.onPlayVoice,
  });

  @override
  Widget build(BuildContext context) {
    final isFromMe = message.isFromMe;
    final alignment = isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (showTimestamp && _shouldShowTimestamp())
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Text(
                _formatTimestamp(message.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
          
          Row(
            mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isFromMe && showAvatar)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildAvatar(),
                ),
              
              Flexible(
                child: GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getBubbleColor(),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.replyToId != null)
                              _buildReplyPreview(),
                            
                            _buildMessageContent(),
                            
                            if (message.hasAttachments)
                              _buildAttachments(),
                            
                            if (message.hasVoiceMessage)
                              _buildVoiceMessage(),
                            
                            _buildMessageFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              if (isFromMe && showAvatar)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  child: _buildAvatar(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accentGold.withOpacity(0.2),
        border: Border.all(
          color: AppTheme.accentGold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: message.senderAvatar != null
            ? Image.network(
                message.senderAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAvatarFallback(),
              )
            : _buildAvatarFallback(),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final initials = message.senderName
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .take(2)
        .join('');
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGold.withOpacity(0.3),
            AppTheme.accentGold.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppTheme.accentGold,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.accentGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: AppTheme.accentGold.withOpacity(0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to message...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case 'text':
        return Text(
          message.content ?? '',
          style: TextStyle(
            color: AppTheme.accentGold.withOpacity(0.9),
            fontSize: 15,
            height: 1.4,
          ),
        );
      case 'system':
        return Text(
          message.content ?? '',
          style: TextStyle(
            color: AppTheme.accentGold.withOpacity(0.6),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAttachments() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: message.attachments.map((attachment) => 
          _buildAttachmentItem(attachment)
        ).toList(),
      ),
    );
  }

  Widget _buildAttachmentItem(ChatAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildAttachmentIcon(attachment),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.originalFilename,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  attachment.displaySize,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.download,
            size: 20,
            color: AppTheme.accentGold.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentIcon(ChatAttachment attachment) {
    IconData icon;
    Color color;

    if (attachment.isImage) {
      icon = Icons.image;
      color = Colors.blue;
    } else if (attachment.isVideo) {
      icon = Icons.videocam;
      color = Colors.red;
    } else if (attachment.isAudio) {
      icon = Icons.audiotrack;
      color = Colors.green;
    } else if (attachment.isDocument) {
      icon = Icons.description;
      color = Colors.orange;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: AppTheme.accentGold.withOpacity(0.8),
        size: 24,
      ),
    );
  }

  Widget _buildVoiceMessage() {
    final voiceMessage = message.voiceMessage!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPlayVoice,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentGold.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.play_arrow,
                color: AppTheme.accentGold,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice message',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  voiceMessage.duration,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _buildWaveform(voiceMessage.waveform ?? []),
        ],
      ),
    );
  }

  Widget _buildWaveform(List<double> waveform) {
    return SizedBox(
      width: 60,
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: waveform.map((amplitude) {
          return Container(
            width: 2,
            height: 2 + (amplitude * 20),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.6),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (message.isEdited)
                Text(
                  'edited',
                  style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
                ),
              if (message.isEdited && message.reactions.isNotEmpty)
                const SizedBox(width: 8),
              if (message.reactions.isNotEmpty)
                _buildReactions(),
            ],
          ),
          Row(
            children: [
              if (message.isRead)
                Icon(
                  Icons.done_all,
                  size: 16,
                  color: AppTheme.accentGold.withOpacity(0.7),
                )
              else
                Icon(
                  Icons.done,
                  size: 16,
                  color: Colors.white.withOpacity(0.5),
                ),
              const SizedBox(width: 4),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        message.reactions.join(' '),
        style: TextStyle(
          color: AppTheme.accentGold.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getBubbleColor() {
    if (message.isFromMe) {
      return AppTheme.accentGold.withOpacity(0.2);
    } else {
      return Colors.white.withOpacity(0.1);
    }
  }

  bool _shouldShowTimestamp() {
    // Show timestamp every 5 messages or if it's a new hour
    return true; // Simplified for now
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inHours > 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
