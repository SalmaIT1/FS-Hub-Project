import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/luxury/luxury_app_bar.dart';
import '../../widgets/glass_notification_card.dart';
import '../../services/employee_service.dart';
import '../../services/auth_service.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> filteredNotifications = [];
  String _selectedFilter = 'All';
  bool _isLoading = true;
  bool _isMarkingAllAsRead = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      setState(() {
        _userId = user['id'];
      });
      await _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (_userId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await EmployeeService.getUserNotifications(_userId!);
      if (result['success'] && mounted) {
        setState(() {
          notifications = List<Map<String, dynamic>>.from(result['data']);
          _applyFilter();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      case 'System':
        filtered = filtered.where((n) => n['type'] == 'system').toList();
        break;
      case 'All':
      default:
        // No filter applied
        break;
    }

    setState(() {
      filteredNotifications = filtered;
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
    } catch (e) {
      // Handle error silently or show snackbar
    }
  }

  Future<void> _markAllAsRead() async {
    if (_userId == null) return;
    
    setState(() {
      _isMarkingAllAsRead = true;
    });

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
      if (mounted) {
        setState(() {
          _isMarkingAllAsRead = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: LuxuryScaffold(
        title: 'Notifications',
        subtitle: '${filteredNotifications.length} items',
        isPremium: true,
        actions: [
          if (!_isMarkingAllAsRead)
            LuxuryAppBarAction(
              icon: Icons.done_all_outlined,
              onPressed: _markAllAsRead,
            )
          else
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
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
          child: SafeArea(
            child: Column(
              children: [
                // Filter Segmented Control
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isDark 
                          ? Colors.white.withOpacity(0.08) 
                          : Colors.black.withOpacity(0.04),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildFilterButton('All', isDark),
                        _buildFilterButton('Unread', isDark),
                        _buildFilterButton('Demands', isDark),
                        _buildFilterButton('System', isDark),
                      ],
                    ),
                  ),
                ),

                // Notifications List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : filteredNotifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none_outlined,
                                    size: 64,
                                    color: isDark 
                                        ? Colors.white.withOpacity(0.6) 
                                        : Colors.black.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notifications',
                                    style: TextStyle(
                                      color: isDark 
                                          ? Colors.white.withOpacity(0.6) 
                                          : Colors.black.withOpacity(0.4),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadNotifications,
                              child: ListView.separated(
                                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                                itemCount: filteredNotifications.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final notification = filteredNotifications[index];
                                  return GlassNotificationCard(
                                    title: notification['title'],
                                    message: notification['message'],
                                    timestamp: notification['timestamp'],
                                    isRead: notification['isRead'],
                                    type: notification['type'],
                                    onTap: () {
                                      _markAsRead(notification['id']);
                                      // Navigate to related entity based on type
                                      _navigateToRelatedEntity(notification);
                                    },
                                    onMarkAsRead: () => _markAsRead(notification['id']),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String filter, bool isDark) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
            _applyFilter();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isSelected
                ? const Color(0xFFFFD700).withOpacity(0.2)
                : Colors.transparent,
          ),
          child: Center(
            child: Text(
              filter,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFFFFD700)
                    : isDark 
                        ? Colors.white.withOpacity(0.7) 
                        : Colors.black.withOpacity(0.7),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToRelatedEntity(Map<String, dynamic> notification) {
    // Implement navigation based on notification type
    // For example, if it's a demand notification, navigate to the demand details
    // This would depend on the notification structure and business logic
  }
}