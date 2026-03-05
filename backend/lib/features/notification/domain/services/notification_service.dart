import '../../../chat/presentation/websocket/websocket_server.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationService {
  static final _repository = NotificationRepository();

  static Future<Map<String, dynamic>> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final id = await _repository.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
      );

      // REAL-TIME BROADCAST: Notify the user immediately via WebSocket
      try {
        final instance = WebSocketServer.instance;
        if (instance != null) {
          WebSocketServer.broadcastNotification(userId, {
            'id': id,
            'title': title,
            'message': message,
            'type': type,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        print('[NotificationService] Broadcast failed: $e');
      }

      return {
        'success': true,
        'message': 'Notification created',
        'data': {'id': id}
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to create: $e'};
    }
  }

  static Future<Map<String, dynamic>> getUserNotifications(String userId, {String? filter}) async {
    try {
      final notifications = await _repository.getUserNotifications(userId, filter: filter);
      return {'success': true, 'data': notifications.map((n) => n.toJson()).toList()};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch: $e'};
    }
  }

  static Future<Map<String, dynamic>> getUnreadNotificationCount(String userId) async {
    try {
      final count = await _repository.getUnreadNotificationCount(userId);
      return {'success': true, 'data': {'count': count}};
    } catch (e) {
      return {'success': false, 'message': 'Failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId, String userId) async {
    try {
      await _repository.markAsRead(notificationId, userId);
      return {'success': true, 'message': 'Marked as read'};
    } catch (e) {
      return {'success': false, 'message': 'Failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead(String userId) async {
    try {
      await _repository.markAllAsRead(userId);
      return {'success': true, 'message': 'All marked as read'};
    } catch (e) {
      return {'success': false, 'message': 'Failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> getNotificationById(String notificationId, String userId) async {
    try {
      final notification = await _repository.getNotificationById(notificationId, userId);
      if (notification == null) return {'success': false, 'message': 'Not found'};
      return {'success': true, 'data': notification.toJson()};
    } catch (e) {
      return {'success': false, 'message': 'Failed: $e'};
    }
  }
}
