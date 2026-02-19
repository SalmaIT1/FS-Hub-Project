import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../chat/domain/chat_entities.dart';
import '../../../chat/domain/message_state_machine.dart';
import '../../../chat/state/chat_controller.dart';
import '../../uploads/services/attachment_manager.dart';
import 'message_bubble.dart';
import 'composer_bar.dart';
import '../../../core/state/settings_controller.dart';

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
    
    // Initialize attachment manager
    _attachmentManager = AttachmentManager(
      context.read<ChatController>().repository.uploads,
    );
    
    // Load current user ID FIRST, then load conversation
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<ChatController>();
      
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
            final threshold = 200.0; // px from bottom considered "near"
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

      // Initial scroll and mark as read after loading messages
      _scrollToBottom();
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[BUILD] chat_thread_page.dart rebuilding');
    final controller = context.watch<ChatController>();
    final settings = context.watch<SettingsController>();
    final messages = controller.currentMessages;
    final isOnline = controller.isOnline;
    print('[BUILD] Chat thread has ${messages.length} messages');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation?.name ?? settings.translate('chat')),
            if (widget.conversation?.type == 'direct')
              Row(
                children: [
                   Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.conversation?.isReceiverOnline == true ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.conversation?.isReceiverOnline == true ? settings.translate('online_badge') : settings.translate('offline_badge'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                      color: widget.conversation?.isReceiverOnline == true ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          if (!isOnline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                label: Text(settings.translate('offline_badge')),
                avatar: const Icon(Icons.cloud_off),
                backgroundColor: Colors.orange[100],
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
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _formatDate(msg.createdAt, settings),
                                    style: Theme.of(context).textTheme.labelSmall,
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
                  top: BorderSide(color: Colors.grey[300]!),
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
