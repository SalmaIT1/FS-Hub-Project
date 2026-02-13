import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/chat_entities.dart';
import '../state/chat_controller.dart';
import 'chat_thread_page.dart';

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

class _ConversationListPageState extends State<ConversationListPage> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Initialize controller (connects WebSocket) and load conversations
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<ChatController>();
      await controller.init();
      if (mounted) {
        await controller.loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    final conversations = controller.conversations;
    final isOnline = controller.isOnline;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chats'),
        actions: [
          if (!isOnline)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Chip(
                  label: Text('Offline'),
                  avatar: Icon(Icons.cloud_off),
                  backgroundColor: Colors.orange[100],
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showNewConversationDialog(context, controller),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadConversations(),
        child: controller.lastError != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Error loading conversations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        controller.lastError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => controller.loadConversations(),
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                    ),
                  ],
                ),
              )
            : conversations.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No conversations yet'),
                  ],
                ),
              )
            : ListView.separated(
                controller: _scrollController,
                itemCount: conversations.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  return _ConversationTile(conversation: conv);
                },
              ),
      ),
    );
  }
}

/// Single conversation tile
class _ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: conversation.avatarUrl != null
            ? NetworkImage(conversation.avatarUrl!)
            : null,
        child: conversation.avatarUrl == null
            ? Icon(
                conversation.type == 'direct'
                    ? Icons.person
                    : Icons.people,
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(child: Text(conversation.name)),
          if (conversation.typingUserIds.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.keyboard, size: 16, color: Colors.blue),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.lastMessage ?? 'No messages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: conversation.lastMessage == null
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
          Text(
            _formatTime(conversation.lastMessageAt),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (conversation.unreadCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (conversation.isArchived)
            Icon(Icons.archive, size: 16, color: Colors.grey),
        ],
      ),
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
      return '${diff.inDays}d ago';
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
    return AlertDialog(
      title: Text('Start a conversation'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _usersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading users: ${snapshot.error}'),
                    );
                  }

                  final users = snapshot.data ?? [];
                  final searchText = _searchController.text.toLowerCase();
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
                    return Center(child: Text('No users found'));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final firstName = user['firstName'] ?? '';
                      final lastName = user['lastName'] ?? '';
                      final fullName =
                          '$firstName $lastName'.trim().isEmpty
                              ? user['username']
                              : '$firstName $lastName';

                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(fullName),
                        subtitle: Text(user['username'] ?? ''),
                        onTap: () async {
                          try {
                            final userId = user['id'] is int 
                                ? user['id'] as int 
                                : int.parse(user['id'].toString());
                            final conversation =
                                await widget.controller
                                    .createConversation(userId);
                            if (conversation != null) {
                              widget.onConversationCreated(conversation);
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
