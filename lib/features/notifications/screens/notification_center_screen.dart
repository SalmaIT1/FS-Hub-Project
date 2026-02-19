import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../widgets/glass_notification_card.dart';
import '../../employees/services/employee_service.dart';
import '../../auth/data/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> filteredNotifications = [];
  String _selectedFilter = 'All';
  bool _isLoading = true;
  bool _isMarkingAllAsRead = false;
  String? _userId;
  
  late AnimationController _staggerController;
  final List<Animation<double>> _staggeredAnimations = [];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initializePage();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _userId = user['id'];
        });
        await _loadNotifications();
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (_userId == null) return;
    
    if (mounted) setState(() => _isLoading = true);

    try {
      final result = await EmployeeService.getUserNotifications(_userId!);
      if (result['success'] && mounted) {
        setState(() {
          notifications = List<Map<String, dynamic>>.from(result['data']);
          _applyFilter();
          _isLoading = false;
          _prepareAnimations();
          _staggerController.reset();
          _staggerController.forward();
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prepareAnimations() {
    _staggeredAnimations.clear();
    final count = filteredNotifications.length > 10 ? 10 : filteredNotifications.length;
    for (int i = 0; i < count; i++) {
      _staggeredAnimations.add(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
        ),
      );
    }
  }

  void _applyFilter() {
    List<Map<String, dynamic>> filtered = List.from(notifications);

    switch (_selectedFilter) {
      case 'Unread':
        filtered = filtered.where((n) => n['isRead'] == false).toList();
        break;
      case 'Demands':
        filtered = filtered.where((n) => n['type'] == 'demand').toList();
        break;
      case 'Recent':
        filtered = filtered.take(5).toList();
        break;
      case 'All':
      default:
        break;
    }

    setState(() {
      filteredNotifications = filtered;
      _prepareAnimations();
      _staggerController.reset();
      _staggerController.forward();
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    if (_userId == null) return;
    
    try {
      final result = await EmployeeService.markNotificationAsRead(notificationId, _userId!);
      if (result['success'] && mounted) {
        setState(() {
          final index = notifications.indexWhere((n) => n['id'] == notificationId);
          if (index != -1) {
            notifications[index]['isRead'] = true;
          }
          _applyFilter();
        });
      }
    } catch (e) {}
  }

  Future<void> _markAllAsRead() async {
    if (_userId == null) return;
    
    setState(() => _isMarkingAllAsRead = true);

    try {
      final result = await EmployeeService.markAllNotificationsAsRead(_userId!);
      if (result['success'] && mounted) {
        setState(() {
          for (var notification in notifications) {
            notification['isRead'] = true;
          }
          _applyFilter();
          _isMarkingAllAsRead = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isMarkingAllAsRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = notifications.where((n) => !n['isRead']).length;

    return LuxuryScaffold(
      title: 'Communications',
      subtitle: unreadCount > 0 ? '$unreadCount unread alerts' : 'Intelligence Center',
      isPremium: true,
      actions: [
        if (unreadCount > 0)
          _isMarkingAllAsRead
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGold))
              : LuxuryAppBarAction(
                  icon: Icons.checklist_rounded,
                  onPressed: _markAllAsRead,
                  isPremium: true,
                ),
      ],
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
        child: Column(
          children: [
            _buildFilterRow(isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
                  : filteredNotifications.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          color: AppTheme.accentGold,
                          onRefresh: _loadNotifications,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredNotifications.length,
                            itemBuilder: (context, index) {
                              final notification = filteredNotifications[index];
                              final animationIdx = index < _staggeredAnimations.length ? index : _staggeredAnimations.length - 1;
                              
                              return _buildAnimatedItem(
                                index,
                                animationIdx,
                                GlassNotificationCard(
                                  title: notification['title'],
                                  message: notification['message'],
                                  timestamp: notification['timestamp'],
                                  isRead: notification['isRead'],
                                  type: notification['type'],
                                  onTap: () {
                                    _markAsRead(notification['id']);
                                    _navigateToRelatedEntity(notification);
                                  },
                                  onMarkAsRead: () => _markAsRead(notification['id']),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, int animIndex, Widget child) {
    return AnimatedBuilder(
      animation: _staggeredAnimations[animIndex],
      builder: (context, child) {
        final value = _staggeredAnimations[animIndex].value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildFilterRow(bool isDark) {
    final filters = ['All', 'Unread', 'Demands', 'Recent'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((f) => _buildFilterChip(f, isDark)).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter, bool isDark) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
          _applyFilter();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppTheme.accentGold, const Color(0xFF8B6914)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: !isSelected 
              ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03))
              : null,
          border: Border.all(
            color: isSelected 
                ? Colors.transparent 
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          filter,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 64,
              color: AppTheme.accentGold.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Zen Protocol Active',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending transmissions found.',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRelatedEntity(Map<String, dynamic> notification) {
    // Logic for routing based on notification payload
  }
}
