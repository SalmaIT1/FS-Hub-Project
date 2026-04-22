import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/composer_bar.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';

class ChatThreadPage extends StatefulWidget {
  final String conversationId;
  final ConversationEntity? conversation;

  const ChatThreadPage({
    super.key,
    required this.conversationId,
    this.conversation,
  });

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
    
    _attachmentManager = AttachmentManager();
    
    // Initialize attachment manager after we have context
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<ChatController>();
      _attachmentManager.repository = controller.repository;
      
      // INITIALIZE WebSocket connection first (this must happen early)
      await controller.init();
      if (!mounted) return;
      
      // JOIN this conversation on WebSocket (subscribe to room)
      controller.joinConversation(widget.conversationId);
      if (!mounted) return;
      
      // Get current user ID from JWT BEFORE loading messages
      final userId = await controller.getCurrentUserId();
      if (!mounted) return;
      
      setState(() {
        _currentUserId = userId;
      });
      
      // NOW load messages with userId available
      await controller.setCurrentConversation(widget.conversationId);
      if (!mounted) return;

      // Scroll to bottom AFTER the first frame so the ListView is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToBottom();
      });

      // Track previous message count and add controller listener for new messages
      _prevMessageCount = controller.currentMessages.length;
      _controllerListener = () {
        if (!mounted) return;
        final msgs = controller.currentMessages;
        final currCount = msgs.length;

        // If new messages arrived
        if (currCount > _prevMessageCount) {
          // Only auto-scroll if user is near bottom to avoid disrupting manual scroll
          if (_scrollController.hasClients) {
            final max = _scrollController.position.maxScrollExtent;
            final pos = _scrollController.position.pixels;
            const threshold = 200.0; // px from bottom considered "near"
            if (pos >= (max - threshold)) {
              _scrollToBottom();
            }
          } else {
            _scrollToBottom();
          }
        }

        _prevMessageCount = currCount;
      };

      controller.addListener(_controllerListener!);

      await controller.markConversationAsRead();
    });
  }

  @override
  void dispose() {
    // Remove controller listener if set
    try {
      final controller = context.read<ChatController>();
      if (_controllerListener != null) controller.removeListener(_controllerListener!);
    } catch (_) {}

    // Dispose attachment manager
    _attachmentManager.dispose();

    _scrollController.dispose();
    super.dispose();
  }

  /// Instant jump to bottom — used on initial load so there's no visible scroll animation.
  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  /// Animated scroll — used when a new message arrives.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      // Controller not yet attached; retry after next frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final settings = context.watch<SettingsController>();
    final messages = controller.currentMessages;
    final isOnline = controller.isOnline;
    final conversation = controller.currentConversation ?? widget.conversation;
    final name = conversation?.name ?? settings.translate('chat');
    
    String? initials;
    if (name.isNotEmpty && name != settings.translate('chat')) {
      final parts = name.trim().split(' ');
      if (parts.length > 1) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Scaffold(
      appBar: LuxuryAppBar(
        title: name,
        avatarUrl: conversation?.avatarUrl,
        initials: initials,
        isGroup: conversation?.type == 'group',
        subtitle: conversation?.typingUserIds.isNotEmpty == true
            ? settings.translate('typing')
            : (conversation?.type == 'direct')
                ? (conversation?.isOnline == true
                    ? settings.translate('online_badge')
                    : settings.translate('offline_badge'))
                : null,
        showBackButton: true,
        onBackPress: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
        isPremium: true,
        actions: [
          if (!isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        settings.translate('offline_badge'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: messages.isEmpty
                ? Center(child: Text(settings.translate('no_messages_yet')))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final prevMsg = index > 0 ? messages[index - 1] : null;
                      
                      // Show date separator
                      final showDateSeparator = prevMsg == null ||
                          !_sameDay(msg.createdAt, prevMsg.createdAt);

                      return Column(
                        children: [
                          if (showDateSeparator)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _formatDate(msg.createdAt, settings),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white60
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          MessageBubble(
                            message: msg,
                            isFromCurrentUser: _currentUserId != null && msg.senderId == _currentUserId,
                            isGroupChat: widget.conversation?.type == 'group',
                            onRetry: msg.state == MessageState.failed
                                ? () => controller.retryMessage(msg.id)
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Composer bar
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[300]!,
                  ),
                ),
              ),
              child: ComposerBar(
                conversationId: widget.conversationId,
                onSendMessage: (content, uploadIds, {voiceMetadata}) {
                  controller.sendMessageWithAttachments(content, uploadIds, voiceMetadata: voiceMetadata);
                  _scrollToBottom();
                },
                attachmentManager: _attachmentManager,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime dt, SettingsController settings) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (_sameDay(dt, now)) {
      return settings.translate('today');
    } else if (_sameDay(dt, yesterday)) {
      return settings.translate('yesterday');
    } else {
      return '${dt.month}/${dt.day}/${dt.year}';
    }
  }
}



