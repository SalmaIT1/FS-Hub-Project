import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/design_tokens.dart';
import '../domain/chat_entities.dart';
import '../domain/message_state_machine.dart';
import '../state/chat_controller.dart';
import '../data/attachment_manager.dart';
import 'message_bubble.dart';
import 'composer_bar.dart';
import 'avatar_helper.dart';

/// Chat thread screen — premium dark glassmorphism design
class ChatThreadPage extends StatefulWidget {
  final String conversationId;
  final ConversationEntity? conversation;

  const ChatThreadPage({
    Key? key,
    required this.conversationId,
    this.conversation,
  }) : super(key: key);

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  late ScrollController _scrollController;
  String? _currentUserId;
  int _prevMessageCount = 0;
  VoidCallback? _controllerListener;
  late AttachmentManager _attachmentManager;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _attachmentManager = AttachmentManager(
      context.read<ChatController>().repository.uploads,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<ChatController>();

      // Only init (connect socket + load employees) if not already done
      if (!controller.isInitialized) {
        await controller.init();
      }
      if (!mounted) return;

      // Get userId and join conversation in parallel
      final userIdFuture = controller.getCurrentUserId();
      controller.joinConversation(widget.conversationId);

      final userId = await userIdFuture;
      if (!mounted) return;

      setState(() => _currentUserId = userId);

      await controller.setCurrentConversation(widget.conversationId);
      if (!mounted) return;

      _prevMessageCount = controller.currentMessages.length;
      _controllerListener = () {
        if (!mounted) return;
        final msgs = controller.currentMessages;
        final currCount = msgs.length;
        if (currCount > _prevMessageCount) {
          if (_scrollController.hasClients) {
            final pos = _scrollController.position.pixels;
            if (pos <= 200) _scrollToNewest();
          } else {
            _scrollToNewest();
          }
        }
        _prevMessageCount = currCount;
      };

      controller.addListener(_controllerListener!);
      // Mark as read in background without blocking UI
      controller.markConversationAsRead();
    });
  }

  @override
  void dispose() {
    try {
      final controller = context.read<ChatController>();
      if (_controllerListener != null) {
        controller.removeListener(_controllerListener!);
      }
    } catch (_) {}
    _attachmentManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNewest() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // In reverse:true, 0.0 is the bottom (newest)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final messages = controller.currentMessages;
    final isOnline = controller.isOnline;

    // Resolve conversation: prefer passed-in object, fall back to controller cache
    final conversation = widget.conversation ??
        controller.conversations
            .cast<ConversationEntity?>()
            .firstWhere(
              (c) => c?.id == widget.conversationId,
              orElse: () => null,
            );

    return Scaffold(
      backgroundColor: DesignTokens.baseDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom App Bar ─────────────────────────────────────
            _ChatThreadAppBar(
              conversation: conversation,
              isContactOnline: conversation?.isOnline ?? false,
            ),

            // ── Message list ───────────────────────────────────────
            Expanded(
              child: _buildMessageList(context, controller, messages, conversation),
            ),

            // ── Composer ───────────────────────────────────────────
            _ComposerWrapper(
              conversationId: widget.conversationId,
              attachmentManager: _attachmentManager,
              onSendMessage: (content, uploadIds, {voiceMetadata, localPaths}) {
                controller.sendMessageWithAttachments(
                  content,
                  uploadIds,
                  voiceMetadata: voiceMetadata,
                  localPaths: localPaths,
                );
                _scrollToNewest();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, ChatController controller,
      List<ChatMessage> messages, ConversationEntity? conversation) {
    // Still loading: show a skeleton while awaiting first fetch
    if (_currentUserId == null) {
      return _MessageSkeleton();
    }

    if (messages.isEmpty) {
      return _EmptyThreadState();
    }

    // messages are sorted oldest→newest; reversed so index 0 is newest (bottom of screen)
    final reversedMessages = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // 0 = bottom = newest message
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: reversedMessages.length,
      itemBuilder: (context, index) {
        final msg = reversedMessages[index];

        // The "next" item up the screen (in reversed list) is the older message at index + 1
        final olderMsg = index + 1 < reversedMessages.length ? reversedMessages[index + 1] : null;

        // Show a date separator ABOVE this message when crossing a day boundary
        // In a reversed list, "above" means rendered AFTER (higher index)
        final showDateSeparator =
            olderMsg != null && !_sameDay(msg.createdAt, olderMsg.createdAt);

        return Column(
          children: [
            // Date separator goes on top of the older day's first visible message
            if (showDateSeparator) _DateSeparator(date: msg.createdAt),
            MessageBubble(
              message: msg,
              isFromCurrentUser: _currentUserId != null &&
                  msg.senderId == _currentUserId,
              isGroupChat: conversation?.type == 'group',
              onRetry: msg.state == MessageState.failed
                  ? () => controller.retryMessage(msg.id)
                  : null,
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom App Bar
// ─────────────────────────────────────────────────────────────────────────────
class _ChatThreadAppBar extends StatelessWidget {
  final ConversationEntity? conversation;
  final bool isContactOnline;

  const _ChatThreadAppBar({
    required this.conversation,
    required this.isContactOnline,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final isGroup = conversation?.type == 'group';
    
    // Resolve avatar
    String? resolvedAvatar;
    if (conversation != null && conversation!.type == 'direct' && conversation!.receiverId != null) {
      // Prioritize cache for direct chats
      resolvedAvatar = controller.getAvatarForUser(conversation!.receiverId!);
    }
    
    // Fallback to conversation data
    resolvedAvatar ??= conversation?.avatarUrl;
    
    // Resolve name
    String displayName = conversation?.name ?? 'Chat';
    if (conversation != null && conversation!.type == 'direct' && conversation!.receiverId != null) {
      displayName = controller.getNameForUser(conversation!.receiverId!) ?? displayName;
    }
    if (displayName.isEmpty) displayName = 'Unknown';



    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceGlass.withOpacity(0.85),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: DesignTokens.textLight),
                onPressed: () => Navigator.pop(context),
              ),

              // Avatar
              AvatarHelper.buildAvatar(
                resolvedAvatar,
                size: 40,
                isGroup: isGroup,
              ),
              const SizedBox(width: 12),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: DesignTokens.bodyL.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isContactOnline
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isContactOnline ? 'Active now' : 'Offline',
                          style: DesignTokens.caption.copyWith(
                            color: isContactOnline
                                ? const Color(0xFF4CAF50)
                                : DesignTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: Icon(Icons.more_vert_rounded,
                    color: DesignTokens.textSecondary),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date separator
// ─────────────────────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: DesignTokens.surfaceGlass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                _label(),
                style: DesignTokens.caption.copyWith(
                  color: DesignTokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty thread state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyThreadState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  DesignTokens.accentGold.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: Icon(
              Icons.waving_hand_rounded,
              size: 32,
              color: DesignTokens.accentGold.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Say hello!',
            style: DesignTokens.bodyL.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to send a message.',
            style: DesignTokens.bodyM,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Composer wrapper with top border glow
// ─────────────────────────────────────────────────────────────────────────────
class _ComposerWrapper extends StatelessWidget {
  final String conversationId;
  final AttachmentManager attachmentManager;
  final Function(String, List<String>,
      {Map<String, dynamic>? voiceMetadata, List<String>? localPaths}) onSendMessage;

  const _ComposerWrapper({
    required this.conversationId,
    required this.attachmentManager,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceGlass.withOpacity(0.9),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ComposerBar(
              conversationId: conversationId,
              onSendMessage: onSendMessage,
              attachmentManager: attachmentManager,
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Message skeleton (loading state)
// ─────────────────────────────────────────────────────────────────────────────
class _MessageSkeleton extends StatefulWidget {
  @override
  State<_MessageSkeleton> createState() => _MessageSkeletonState();
}

class _MessageSkeletonState extends State<_MessageSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _bubble(double width, bool isRight) {
    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (_, __) => Opacity(
          opacity: _opacity.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            width: width,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _bubble(120, true),
        _bubble(200, false),
        _bubble(160, true),
        _bubble(240, false),
        _bubble(100, true),
        _bubble(180, false),
        _bubble(140, true),
        _bubble(220, false),
      ],
    );
  }
}
