import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../shared/models/notification_model.dart' as AppNotification;
import '../features/notifications/services/notification_service.dart';

class NotificationDrawer extends StatefulWidget {
  final String userId;
  final String userRole;

  const NotificationDrawer({
    Key? key,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends State<NotificationDrawer> {
  List<AppNotification.Notification> notifications = [];
  bool isLoading = true;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await NotificationService.getUserNotifications(widget.userId);

      if (mounted && result['success']) {
        final List<dynamic> notificationData = result['data'];
        notifications = notificationData.map((item) => AppNotification.Notification.fromJson(item)).toList();
        
        // Calculate unread count
        unreadCount = notifications.where((notification) => !notification.isRead).length;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final result = await NotificationService.markAsRead(notificationId, widget.userId);

      if (mounted && result['success']) {
        // Update local state
        final index = notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          notifications[index] = AppNotification.Notification(
            id: notifications[index].id,
            userId: notifications[index].userId,
            title: notifications[index].title,
            message: notifications[index].message,
            type: notifications[index].type,
            isRead: true,
            timestamp: notifications[index].timestamp,
          );
          
          // Recalculate unread count
          unreadCount = notifications.where((notification) => !notification.isRead).length;
          
          setState(() {});
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notification as read: $e')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final result = await NotificationService.markAllAsRead(widget.userId);

      if (mounted && result['success']) {
        // Update local state
        notifications = notifications.map((notification) => AppNotification.Notification(
          id: notification.id,
          userId: notification.userId,
          title: notification.title,
          message: notification.message,
          type: notification.type,
          isRead: true,
          timestamp: notification.timestamp,
        )).toList();
        
        unreadCount = 0;
        
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking all notifications as read: $e')),
      );
    }
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'demand':
        return '📋';
      case 'password_reset':
        return '🔑';
      case 'system':
        return '⚙️';
      case 'alert':
        return '⚠️';
      default:
        return '🔔';
    }
  }

  String _formatTimestamp(String timestampString) {
    try {
      final timestamp = DateTime.parse(timestampString);
      return DateFormat('MMM dd, yyyy - HH:mm').format(timestamp);
    } catch (e) {
      return timestampString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.blue,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$unreadCount Unread',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (unreadCount > 0)
                      TextButton(
                        onPressed: _markAllAsRead,
                        child: const Text(
                          'Mark All Read',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Refresh button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),

          // Notifications list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No notifications',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final isUnread = !notification.isRead;
                          
                          return Dismissible(
                            key: Key(notification.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) {
                              _markAsRead(notification.id);
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: Colors.blue,
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isUnread ? Colors.blue : Colors.grey[300],
                                foregroundColor: isUnread ? Colors.white : Colors.black,
                                child: Text(_getNotificationIcon(notification.type)),
                              ),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.message,
                                    style: TextStyle(
                                      color: isUnread ? Colors.black87 : Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(notification.timestamp),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isUnread
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                _markAsRead(notification.id);
                              },
                              tileColor: isUnread ? Colors.blue[50] : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}