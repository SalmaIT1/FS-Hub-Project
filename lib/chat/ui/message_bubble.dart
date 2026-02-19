import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/design_tokens.dart';
import '../domain/chat_entities.dart';
import '../domain/message_state_machine.dart';
import '../state/chat_controller.dart';
import 'media_components.dart';
import 'avatar_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sizing constants — keep everything consistent
// ─────────────────────────────────────────────────────────────────────────────
const double _kMinBubbleWidth = 90.0;   // never narrower than this
const double _kMaxBubbleFraction = 0.72; // max % of screen width
const double _kAvatarSize = 30.0;
const double _kAvatarGap = 6.0;

/// Premium message bubble widget
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
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * _kMaxBubbleFraction;

    return Padding(
      padding: EdgeInsets.only(
        // Indent the opposite side so bubbles don't span full width
        left: isFromCurrentUser ? screenWidth * 0.18 : 12,
        right: isFromCurrentUser ? 12 : screenWidth * 0.18,
        top: 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment: isFromCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sender avatar (group chats, received only)
          if (!isFromCurrentUser && isGroupChat)
            Padding(
              padding: const EdgeInsets.only(
                  right: _kAvatarGap, bottom: 4),
              child: _SenderAvatar(message: message),
            ),

          // Bubble — constrained width, never below minimum
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: _kMinBubbleWidth,
              maxWidth: maxWidth,
            ),
            child: _buildBubble(context),
          ),

          // Delivery tick (sent messages only)
          if (isFromCurrentUser)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: _DeliveryIcon(
                  state: message.state, onRetry: onRetry),
            ),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final isMe = isFromCurrentUser;

    return GestureDetector(
      onTap: onRetap,
      child: Container(
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFFC9A24D), Color(0xFF8B6914)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : const Color(0xFF242424),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: isMe
                  ? DesignTokens.accentGold.withOpacity(0.18)
                  : Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: isMe
              ? null
              : Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isMe = isFromCurrentUser;

    // For text messages we use the "trailing spacer" trick:
    // append an invisible widget the same width as the timestamp so the
    // text wraps naturally and the timestamp never overlaps it.
    if (message.type == 'text') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sender name in group chats
          if (!isMe && isGroupChat && message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                message.senderName!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.accentGold,
                  letterSpacing: 0.3,
                ),
              ),
            ),

          // Text + invisible timestamp spacer in the same flow
          _TextWithTimestamp(
            text: message.content,
            timestamp: _formatTime(message.createdAt),
            isEdited: message.isEdited,
            isMe: isMe,
          ),
        ],
      );
    }

    // Non-text content: attachment / voice
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMe && isGroupChat && message.senderName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              message.senderName!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: DesignTokens.accentGold,
                letterSpacing: 0.3,
              ),
            ),
          ),

        if (message.type == 'audio' || message.type == 'voice')
          _buildVoiceNotePreview(context)
        else
          _buildAttachmentPreview(context),

        // Timestamp below media
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.bottomRight,
          child: _TimestampRow(
            timestamp: _formatTime(message.createdAt),
            isEdited: message.isEdited,
            isMe: isMe,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentPreview(BuildContext context) {
    if (message.attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              message.content,
              style: TextStyle(
                color: isFromCurrentUser
                    ? Colors.black.withOpacity(0.9)
                    : DesignTokens.textLight,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
          ),
        ...message.attachments.map((att) => _buildAttachmentTile(context, att)),
      ],
    );
  }

  Widget _buildAttachmentTile(
      BuildContext context, AttachmentEntity attachment) {
    final mimeType = attachment.mimeType;
    if (mimeType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InlineImageBubble(attachment: attachment),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: FileAttachmentBubble(attachment: attachment),
    );
  }

  Widget _buildVoiceNotePreview(BuildContext context) {
    if (message.voiceNote == null) return const SizedBox.shrink();
    return VoiceNoteBubble(voice: message.voiceNote!);
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Text + timestamp in the same text flow (trailing spacer trick)
// The timestamp sits bottom-right and the text wraps around it naturally.
// ─────────────────────────────────────────────────────────────────────────────
class _TextWithTimestamp extends StatelessWidget {
  final String text;
  final String timestamp;
  final bool isEdited;
  final bool isMe;

  const _TextWithTimestamp({
    required this.text,
    required this.timestamp,
    required this.isEdited,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    // Build the timestamp widget so we can measure its width
    final tsWidget = _TimestampRow(
      timestamp: timestamp,
      isEdited: isEdited,
      isMe: isMe,
    );

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Text with a trailing invisible spacer that reserves room for the
        // timestamp on the last line
        Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: text,
                  style: TextStyle(
                    color: isMe
                        ? Colors.black.withOpacity(0.9)
                        : DesignTokens.textLight,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
                // Invisible spacer — same width as timestamp + small gap
                WidgetSpan(
                  child: SizedBox(
                    // Approximate width: ~4 chars timestamp + edited + gap
                    width: isEdited ? 88 : 52,
                    height: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Actual timestamp overlaid at bottom-right
        tsWidget,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable timestamp row
// ─────────────────────────────────────────────────────────────────────────────
class _TimestampRow extends StatelessWidget {
  final String timestamp;
  final bool isEdited;
  final bool isMe;

  const _TimestampRow({
    required this.timestamp,
    required this.isEdited,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final color = isMe
        ? Colors.black.withOpacity(0.45)
        : DesignTokens.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEdited) ...[
          Text(
            'edited · ',
            style: TextStyle(fontSize: 10, color: color, height: 1),
          ),
        ],
        Text(
          timestamp,
          style: TextStyle(fontSize: 10, color: color, height: 1),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sender avatar (group chat)
// ─────────────────────────────────────────────────────────────────────────────
class _SenderAvatar extends StatelessWidget {
  final ChatMessage message;
  const _SenderAvatar({required this.message});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    
    // Resolve avatar
    String? resolvedAvatar = message.senderAvatar;
    if (resolvedAvatar == null || resolvedAvatar.isEmpty) {
      resolvedAvatar = controller.getAvatarForUser(message.senderId);
    }
    
    final initials = (message.senderName ?? controller.getNameForUser(message.senderId) ?? '?')
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return AvatarHelper.buildAvatar(
      resolvedAvatar,
      size: _kAvatarSize,
      initials: initials,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery status icon
// ─────────────────────────────────────────────────────────────────────────────
class _DeliveryIcon extends StatelessWidget {
  final MessageState state;
  final VoidCallback? onRetry;

  const _DeliveryIcon({required this.state, this.onRetry});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case MessageState.draft:
      case MessageState.queued:
        return Icon(Icons.schedule_rounded,
            size: 13, color: DesignTokens.textSecondary);
      case MessageState.uploading:
      case MessageState.sending:
        return const SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: DesignTokens.accentGold,
          ),
        );
      case MessageState.sent:
        return Icon(Icons.done_rounded,
            size: 13, color: DesignTokens.textSecondary);
      case MessageState.delivered:
        return Icon(Icons.done_all_rounded,
            size: 13, color: DesignTokens.textSecondary);
      case MessageState.read:
        return const Icon(Icons.done_all_rounded,
            size: 13, color: DesignTokens.accentGold);
      case MessageState.failed:
        return GestureDetector(
          onTap: onRetry,
          child: const Icon(Icons.error_outline_rounded,
              size: 13, color: Colors.redAccent),
        );
    }
  }
}
