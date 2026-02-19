import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/design_tokens.dart';
import '../domain/chat_entities.dart';
import '../state/chat_controller.dart';
import 'avatar_helper.dart';
import 'group_creation_page.dart';

/// Conversation list screen — premium dark glassmorphism design
class ConversationListPage extends StatefulWidget {
  const ConversationListPage({Key? key}) : super(key: key);

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}
// Trigger hot restart

class _ConversationListPageState extends State<ConversationListPage>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fabAnimController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<ChatController>();
      await controller.init();
      if (mounted) await controller.loadConversations();
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showNewConversationDialog(
      BuildContext context, ChatController controller) {
    final navigator = Navigator.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) => _NewConversationDialog(
        controller: controller,
        onConversationCreated: (conversation) {
          navigator.pushNamed(
            '/chat_thread',
            arguments: {
              'conversationId': conversation.id,
              'conversation': conversation,
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final allConversations = controller.conversations;
    final isOnline = controller.isOnline;

    final conversations = _searchQuery.isEmpty
        ? allConversations
        : allConversations.where((c) {
            final query = _searchQuery.toLowerCase();
            String displayName = c.name;
            if (c.type == 'direct' && c.receiverId != null) {
              displayName = controller.getNameForUser(c.receiverId!) ?? c.name;
            }
            return displayName.toLowerCase().contains(query) ||
                (c.lastMessage?.toLowerCase().contains(query) ?? false);
          }).toList();

    return Scaffold(
      backgroundColor: DesignTokens.baseDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _ChatListHeader(
              isOnline: isOnline,
              onNewChat: () =>
                  _showNewConversationDialog(context, controller),
            ),

            // ── Search bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SearchBar(controller: _searchController),
            ),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: DesignTokens.accentGold,
                backgroundColor: DesignTokens.surfaceGlass,
                onRefresh: () => controller.loadConversations(),
                child: _buildBody(context, controller, conversations),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ChatController controller,
      List<ConversationEntity> conversations) {
    if (controller.lastError != null) {
      return _ErrorState(
        error: controller.lastError!,
        onRetry: () => controller.loadConversations(),
      );
    }

    if (conversations.isEmpty) {
      return _EmptyState(hasSearch: _searchQuery.isNotEmpty);
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        return _ConversationTile(
          conversation: conversations[index],
          index: index,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _ChatListHeader extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onNewChat;

  const _ChatListHeader({required this.isOnline, required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages',
                style: DesignTokens.headingM.copyWith(
                  color: DesignTokens.textLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline
                          ? const Color(0xFF4CAF50)
                          : Colors.orange,
                      boxShadow: [
                        BoxShadow(
                          color: (isOnline
                                  ? const Color(0xFF4CAF50)
                                  : Colors.orange)
                              .withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: DesignTokens.caption.copyWith(
                      color: isOnline
                          ? const Color(0xFF4CAF50)
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // New chat button
          _GlassIconButton(
            icon: Icons.edit_outlined,
            onTap: onNewChat,
            tooltip: 'New conversation',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceGlass.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            style: DesignTokens.bodyL.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search conversations…',
              hintStyle: DesignTokens.bodyM,
              prefixIcon: Icon(
                Icons.search_rounded,
                color: DesignTokens.textSecondary,
                size: 20,
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: DesignTokens.textSecondary, size: 18),
                      onPressed: () => controller.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation tile
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationTile extends StatefulWidget {
  final ConversationEntity conversation;
  final int index;

  const _ConversationTile({
    required this.conversation,
    required this.index,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  void _confirmDelete(BuildContext context, ConversationEntity conv) {
    final controller = Provider.of<ChatController>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Conversation',
          style: DesignTokens.headingS.copyWith(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this conversation? This will only remove it for your account.',
          style: DesignTokens.bodyM.copyWith(color: DesignTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: DesignTokens.bodyM.copyWith(color: DesignTokens.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                await controller.leaveConversation(conv.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conversation deleted'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: DesignTokens.bodyM.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final hasUnread = conv.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              splashColor: DesignTokens.accentGold.withOpacity(0.08),
              highlightColor: DesignTokens.accentGold.withOpacity(0.04),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/chat_thread',
                  arguments: {
                    'conversationId': conv.id,
                    'conversation': conv,
                  },
                );
              },
              onLongPress: () => _confirmDelete(context, conv),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Avatar
                    _ConversationAvatar(conversation: conv),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                                Expanded(
                                child: Consumer<ChatController>(
                                  builder: (context, controller, child) {
                                    String displayName = conv.name;
                                    if (conv.type == 'direct' && conv.receiverId != null) {
                                      displayName = controller.getNameForUser(conv.receiverId!) ?? conv.name;
                                    }
                                    if (displayName.isEmpty) displayName = 'Unknown';
                                    
                                    return Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: DesignTokens.textLight,
                                        fontSize: 15,
                                        fontWeight: hasUnread
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(conv.lastMessageAt),
                                style: DesignTokens.caption.copyWith(
                                  color: hasUnread
                                      ? DesignTokens.accentGold
                                      : DesignTokens.textSecondary,
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (conv.typingUserIds.isNotEmpty) ...[
                                _TypingDots(),
                                const SizedBox(width: 6),
                              ] else
                                Expanded(
                                  child: Text(
                                    conv.lastMessage ?? 'No messages yet',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DesignTokens.bodyM.copyWith(
                                      fontStyle: conv.lastMessage == null
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                      fontWeight: hasUnread
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                      color: hasUnread
                                          ? DesignTokens.textLight
                                              .withOpacity(0.7)
                                          : DesignTokens.textSecondary,
                                    ),
                                  ),
                                ),
                              if (hasUnread) ...[
                                const SizedBox(width: 8),
                                _UnreadBadge(count: conv.unreadCount),
                              ],
                              if (conv.isArchived && !hasUnread) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.archive_outlined,
                                    size: 14,
                                    color: DesignTokens.textSecondary),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationAvatar extends StatelessWidget {
  final ConversationEntity conversation;
  const _ConversationAvatar({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final isGroup = conversation.type == 'group';
    
    // Resolve avatar:
    String? resolvedAvatar;
    if (!isGroup && conversation.receiverId != null) {
      // Prioritize employee cache for direct chats as it's known to work perfectly
      resolvedAvatar = controller.getAvatarForUser(conversation.receiverId!);
    }
    
    // Fallback to conversation data if cache is empty or it's a group
    resolvedAvatar ??= conversation.avatarUrl;
    


    return Stack(
      children: [
        AvatarHelper.buildAvatar(
          resolvedAvatar,
          size: 52,
          isGroup: isGroup,
        ),
        // Online indicator
        if (!isGroup && conversation.isOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: DesignTokens.baseDark,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unread badge
// ─────────────────────────────────────────────────────────────────────────────
class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DesignTokens.accentGold, Color(0xFF8B6914)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.accentGold.withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing dots animation
// ─────────────────────────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = (_controller.value - i * 0.2).clamp(0.0, 1.0);
            final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2))
                .clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 3),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignTokens.accentGold.withOpacity(opacity),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass icon button
// ─────────────────────────────────────────────────────────────────────────────
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              splashColor: DesignTokens.accentGold.withOpacity(0.15),
              onTap: onTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Icon(icon,
                    color: DesignTokens.accentGold, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  DesignTokens.accentGold.withOpacity(0.2),
                  DesignTokens.accentGold.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 36,
              color: DesignTokens.accentGold.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch ? 'No results found' : 'No conversations yet',
            style: DesignTokens.bodyL.copyWith(
              color: DesignTokens.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try a different search term'
                : 'Start a new conversation\nby tapping the edit icon above',
            textAlign: TextAlign.center,
            style: DesignTokens.bodyM,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.1),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 36, color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Error',
              style: DesignTokens.bodyL.copyWith(
                color: DesignTokens.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: DesignTokens.bodyM,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.accentGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New conversation dialog
// ─────────────────────────────────────────────────────────────────────────────
class _NewConversationDialog extends StatefulWidget {
  final ChatController controller;
  final Function(ConversationEntity) onConversationCreated;

  const _NewConversationDialog({
    required this.controller,
    required this.onConversationCreated,
  });

  @override
  State<_NewConversationDialog> createState() =>
      _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _usersFuture = widget.controller.getAvailableUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 560),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceGlass,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
              boxShadow: DesignTokens.glassShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                  child: Row(
                    children: [
                      Text(
                        'New Conversation',
                        style: DesignTokens.headingM.copyWith(fontSize: 20),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: DesignTokens.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Create Group Option
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupCreationPage(
                              controller: widget.controller,
                              onGroupCreated: widget.onConversationCreated,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: DesignTokens.accentGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DesignTokens.accentGold.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: DesignTokens.accentGold.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.group_add_rounded, color: DesignTokens.accentGold, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Create Group Chat',
                              style: DesignTokens.bodyL.copyWith(
                                color: DesignTokens.accentGold,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DesignTokens.accentGold),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: DesignTokens.bodyL.copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search users…',
                        hintStyle: DesignTokens.bodyM,
                        prefixIcon: Icon(Icons.search_rounded,
                            color: DesignTokens.textSecondary, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // User list
                Flexible(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _usersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: DesignTokens.accentGold,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error loading users',
                            style: DesignTokens.bodyM,
                          ),
                        );
                      }

                      final users = snapshot.data ?? [];
                      final searchText =
                          _searchController.text.toLowerCase();
                      final filtered = users
                          .where((user) =>
                              (user['username'] as String)
                                  .toLowerCase()
                                  .contains(searchText) ||
                              (user['firstName'] as String?)
                                      ?.toLowerCase()
                                      .contains(searchText) ==
                                  true ||
                              (user['lastName'] as String?)
                                      ?.toLowerCase()
                                      .contains(searchText) ==
                                  true)
                          .toList();

                      if (filtered.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No users found',
                            style: DesignTokens.bodyM,
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          final firstName = user['firstName'] ?? '';
                          final lastName = user['lastName'] ?? '';
                          final fullName =
                              '$firstName $lastName'.trim().isEmpty
                                  ? user['username']
                                  : '$firstName $lastName';

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                try {
                                  final userId = user['id'].toString();
                                  final conversation = await widget
                                      .controller
                                      .createConversation(userId);
                                  if (conversation != null) {
                                    final messenger = ScaffoldMessenger.of(context);
                                    if (mounted) Navigator.pop(context);
                                    widget.onConversationCreated(
                                        conversation);
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                        content: Text('Error: $e')),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            DesignTokens.accentGold,
                                            const Color(0xFF8B6914),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName,
                                            style: DesignTokens.bodyL
                                                .copyWith(fontSize: 14),
                                          ),
                                          Text(
                                            '@${user['username'] ?? ''}',
                                            style: DesignTokens.caption,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: DesignTokens.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
