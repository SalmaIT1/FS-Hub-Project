import 'dart:ui';
import 'package:provider/provider.dart';
import '../domain/chat_entities.dart';
import '../state/chat_controller.dart';
import 'chat_thread_page.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/luxury/luxury_search_inline.dart';
import '../../../core/state/settings_controller.dart';

/// Conversation list screen
/// 
/// Features:
/// - Last message preview
/// - Unread badge
/// - Typing indicator
/// - Presence indicator
/// - Draft indicator
/// - Pagination
/// - Offline badge
/// - Pull-to-refresh
class ConversationListPage extends StatefulWidget {
  const ConversationListPage({Key? key}) : super(key: key);

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _listController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Initialize controller (connects WebSocket) and load conversations
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<ChatController>();
      await controller.init();
      if (mounted) {
        await controller.loadConversations();
        _listController.forward();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _showNewConversationDialog(BuildContext context, ChatController controller) {
    showDialog(
      context: context,
      builder: (dialogContext) => _NewConversationDialog(
        controller: controller,
        onConversationCreated: (conversation) {
          Navigator.pop(dialogContext);
          Navigator.pushNamed(
            context,
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
    final settings = context.watch<SettingsController>();
    final conversations = controller.conversations
        .where((c) => _searchQuery.isEmpty || 
               c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    final isOnline = controller.isOnline;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LuxuryAppBar(
        title: settings.translate('messages'),
        subtitle: isOnline ? settings.translate('sync_active') : settings.translate('connecting_node'),
        isPremium: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
              ),
              child: const Icon(Icons.add_rounded, color: AppTheme.accentGold, size: 20),
            ),
            onPressed: () => _showNewConversationDialog(context, controller),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: isDark 
                ? [const Color(0xFF0F0F0F), Colors.black]
                : [const Color(0xFFF8F8F8), const Color(0xFFECECEC)],
          ),
        ),
        child: RefreshIndicator(
          color: AppTheme.accentGold,
          onRefresh: () => controller.loadConversations(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
              
              // Search Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: LuxurySearchInline(
                    hintText: settings.translate('search_conversations'),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),

              if (controller.lastError != null)
                SliverFillRemaining(
                  child: _buildErrorState(controller, settings),
                )
              else if (conversations.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(settings),
                )
              else
                SliverPadding(
                   padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final conv = conversations[index];
                        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _listController,
                            curve: Interval(
                              (index / 10).clamp(0.0, 1.0),
                              1.0,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        );

                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: animation.value,
                              child: Transform.translate(
                                offset: Offset(0, 30 * (1 - animation.value)),
                                child: child,
                              ),
                            );
                          },
                          child: _ConversationTile(conversation: conv, settings: settings),
                        );
                      },
                      childCount: conversations.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.forum_outlined, size: 64, color: AppTheme.accentGold.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? settings.translate('silent_horizon') : settings.translate('no_echoes_found'),
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.white70 : Colors.black54,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty 
                ? settings.translate('begin_encrypted_dialogue') 
                : settings.translate('adjust_search_frequency'),
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ChatController controller, SettingsController settings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              settings.translate('encryption_sync_failed'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              controller.lastError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => controller.loadConversations(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(settings.translate('try_reestablishing_connection')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single conversation tile
class _ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final SettingsController settings;

  const _ConversationTile({required this.conversation, required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: _buildAvatar(isDark),
                title: _buildTitle(isDark, context),
                subtitle: _buildSubtitle(isDark, context),
                trailing: _buildTrailing(isDark, context),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/chat_thread',
                    arguments: {
                      'conversationId': conversation.id,
                      'conversation': conversation,
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentGold.withOpacity(0.2),
                AppTheme.accentGold.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: conversation.type == 'direct' && conversation.isReceiverOnline
                  ? const Color(0xFF4CAF50).withOpacity(0.5)
                  : AppTheme.accentGold.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Center(
            child: ClipOval(
              child: (conversation.avatarUrl?.isNotEmpty == true)
                  ? Image.network(
                      conversation.avatarUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
                    )
                  : _buildAvatarPlaceholder(),
            ),
          ),
        ),
        if (conversation.type == 'direct' && conversation.isReceiverOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.transparent,
      child: Icon(
        conversation.type == 'direct' ? Icons.person_rounded : Icons.groups_rounded,
        color: AppTheme.accentGold,
        size: 24,
      ),
    );
  }

  Widget _buildTitle(bool isDark, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            conversation.name.isNotEmpty ? conversation.name : settings.translate('secured_terminal'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (conversation.typingUserIds.isNotEmpty)
          _buildTypingIndicator(isDark),
      ],
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        settings.translate('typing'),
        style: const TextStyle(
          color: Color(0xFF4CAF50),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubtitle(bool isDark, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        conversation.lastMessage ?? settings.translate('no_data_transmission'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black45,
          fontSize: 13,
          fontWeight: conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
          fontStyle: conversation.lastMessage == null ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildTrailing(bool isDark, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatTime(conversation.lastMessageAt),
          style: TextStyle(
            color: conversation.unreadCount > 0 ? AppTheme.accentGold : (isDark ? Colors.white24 : Colors.black26),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (conversation.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentGold, Color(0xFFB8860B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGold.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${conversation.unreadCount}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        else if (conversation.isArchived)
          Icon(Icons.inventory_2_outlined, size: 14, color: isDark ? Colors.white24 : Colors.black26),
      ],
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return settings.translate('yesterday');
    } else if (diff.inDays < 7) {
      return '${diff.inDays}${settings.languageCode == 'fr' ? 'j' : 'd'}';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}

/// Dialog to create a new conversation by selecting a user
class _NewConversationDialog extends StatefulWidget {
  final ChatController controller;
  final Function(ConversationEntity) onConversationCreated;

  const _NewConversationDialog({
    required this.controller,
    required this.onConversationCreated,
  });

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: AppTheme.accentGold),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.translate('establish_neural_link'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            ),
                            Text(
                              settings.translate('select_recipient_encrypted'),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LuxurySearchInline(
                    hintText: settings.translate('lookup_personnel'),
                    onChanged: (val) => setState(() {}),
                    controller: _searchController,
                  ),
                ),
                
                const SizedBox(height: 16),

                // User List
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _usersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Interference detected: ${snapshot.error}'));
                      }

                      final users = snapshot.data ?? [];
                      final searchText = _searchController.text.toLowerCase();
                      final filtered = users
                          .where((user) =>
                              (user['username'] as String).toLowerCase().contains(searchText) ||
                              (user['firstName'] as String?).toString().toLowerCase().contains(searchText) ||
                              (user['lastName'] as String?).toString().toLowerCase().contains(searchText))
                          .toList();

                      if (filtered.isEmpty) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(settings.translate('no_active_personnel'), style: const TextStyle(color: Colors.grey)),
                          ],
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          final fullName = ('${user['firstName'] ?? ''} ${user['lastName'] ?? ''}').trim();
                          final displayName = fullName.isEmpty ? user['username'] : fullName;
                          final isOnline = user['isOnline'] == 1 || user['isOnline'] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.accentGold.withOpacity(0.1),
                                    child: const Icon(Icons.person_rounded, color: AppTheme.accentGold, size: 20),
                                  ),
                                  if (isOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                user['username'] ?? '',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                              ),
                              trailing: isOnline 
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
                                    ),
                                    child: Text(settings.translate('active_badge'), style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 8, fontWeight: FontWeight.bold)),
                                  )
                                : null,
                              onTap: () async {
                                final userId = user['id'].toString();
                                final conversation = await widget.controller.createConversation(userId);
                                if (conversation != null) {
                                  widget.onConversationCreated(conversation);
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
