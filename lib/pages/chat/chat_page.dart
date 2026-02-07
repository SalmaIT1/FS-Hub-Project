import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/employee.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../widgets/luxury/luxury_app_bar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  Conversation? _selectedConversation;
  bool _isLoadingConversations = true;
  bool _isLoadingMessages = false;
  String? _currentUserId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializePage();
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUserId = user['id'];
      });
      await _loadConversations();
    }
  }

  Future<void> _loadConversations() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoadingConversations = true;
    });

    final conversations = await MessageService.getConversations(_currentUserId!);
    
    if (mounted) {
      setState(() {
        _conversations = conversations;
        _isLoadingConversations = false;
      });
    }
  }

  Future<void> _loadMessages(Conversation conversation) async {
    setState(() {
      _selectedConversation = conversation;
      _isLoadingMessages = true;
    });

    final messages = await MessageService.getConversationMessages(conversation.id);
    
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
      });
      
      // Mark conversation as read
      if (_currentUserId != null) {
        await MessageService.markConversationAsRead(conversation.id, _currentUserId!);
      }
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messagesScrollController.hasClients) {
          _messagesScrollController.jumpTo(_messagesScrollController.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _refreshData() async {
    if (_currentUserId == null) return;
    
    // Refresh conversations silently
    final conversations = await MessageService.getConversations(_currentUserId!);
    if (mounted) {
      setState(() {
        _conversations = conversations;
      });
    }
    
    // Refresh messages if a conversation is selected
    if (_selectedConversation != null) {
      final messages = await MessageService.getConversationMessages(_selectedConversation!.id);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedConversation == null || _currentUserId == null) {
      return;
    }

    final content = _messageController.text.trim();
    _messageController.clear();

    final result = await MessageService.sendMessage(
      conversationId: _selectedConversation!.id,
      senderId: _currentUserId!,
      content: content,
    );

    if (result['success']) {
      // Reload messages
      await _loadMessages(_selectedConversation!);
      await _loadConversations(); // Refresh conversation list
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to send message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: LuxuryScaffold(
        title: 'Messages',
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.8),
              radius: 1.2,
              colors: isDark 
                  ? [const Color(0xFF1A1A1A), Colors.black]
                  : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80, left: 20, right: 20),
              child: Row(
                children: [
                  // Conversation List
                  Expanded(
                    flex: 1,
                    child: _buildConversationList(isDark),
                  ),
                  const SizedBox(width: 16),
                  // Message Thread
                  Expanded(
                    flex: 2,
                    child: _buildMessageThread(isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                      ),
                    ),
                    IconButton(
                      onPressed: _showNewConversationDialog,
                      icon: Icon(
                        Icons.add_comment_outlined,
                        color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                      ),
                      tooltip: 'Start New Conversation',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoadingConversations
                    ? const Center(child: CircularProgressIndicator())
                    : _conversations.isEmpty
                        ? Center(
                            child: Text(
                              'No conversations yet',
                              style: TextStyle(
                                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final conversation = _conversations[index];
                              final isSelected = _selectedConversation?.id == conversation.id;
                              
                              return _buildConversationItem(conversation, isSelected, isDark);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationItem(Conversation conversation, bool isSelected, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
              child: Text(
                conversation.otherParticipantName[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherParticipantName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage ?? 'No messages yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageThread(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.3),
            ),
          ),
          child: _selectedConversation == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a conversation to start messaging',
                        style: TextStyle(
                          color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                            child: Text(
                              _selectedConversation!.otherParticipantName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedConversation!.otherParticipantName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Messages
                    Expanded(
                      child: _isLoadingMessages
                          ? const Center(child: CircularProgressIndicator())
                          : _messages.isEmpty
                              ? Center(
                                  child: Text(
                                    'No messages yet. Start the conversation!',
                                    style: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _messagesScrollController,
                                  padding: const EdgeInsets.all(20),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    final isMe = message.senderId == _currentUserId;
                                    return _buildMessageBubble(message, isMe, isDark);
                                  },
                                ),
                    ),
                    // Message Input
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4),
                                ),
                                filled: true,
                                fillColor: isDark 
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.white.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _sendMessage,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.send,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
              child: Text(
                message.senderName[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe 
                    ? const Color(0xFFD4AF37)
                    : isDark 
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.black : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe 
                          ? Colors.black.withOpacity(0.6)
                          : isDark 
                              ? Colors.white.withOpacity(0.5)
                              : Colors.black.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showNewConversationDialog() {
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Start New Conversation'),
              content: SizedBox(
                width: 400,
                height: 300,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search employees...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        // TODO: Implement search functionality
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: FutureBuilder<List<Employee>>(
                        future: EmployeeService.getAllEmployees(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }
                          
                          final employees = snapshot.data ?? [];
                          final filteredEmployees = employees.where((emp) => 
                            emp.id != null && emp.id != _currentUserId && // Don't show current user
                            (searchController.text.isEmpty || 
                             emp.nom.toLowerCase().contains(searchController.text.toLowerCase()) ||
                             emp.prenom.toLowerCase().contains(searchController.text.toLowerCase()))
                          ).toList();

                          if (filteredEmployees.isEmpty) {
                            return const Center(child: Text('No employees found'));
                          }

                          return ListView.builder(
                            itemCount: filteredEmployees.length,
                            itemBuilder: (context, index) {
                              final employee = filteredEmployees[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text('${employee.prenom[0]}${employee.nom[0]}'),
                                ),
                                title: Text('${employee.prenom} ${employee.nom}'),
                                subtitle: Text(employee.role ?? 'Employee'),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await _startConversationWithUser(employee);
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startConversationWithUser(Employee employee) async {
    if (_currentUserId == null) return;

    try {
      final result = await MessageService.getOrCreateConversation(
        _currentUserId!,
        employee.id!,
      );

      if (result['success']) {
        // Refresh conversations list and select the new one
        await _loadConversations();
        
        // Find and select the new conversation
        final newConversation = _conversations.firstWhere(
          (conv) => conv.otherParticipantId == employee.id!,
          orElse: () => _conversations.first,
        );
        
        await _loadMessages(newConversation);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Conversation started with ${employee.prenom} ${employee.nom}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to start conversation')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}