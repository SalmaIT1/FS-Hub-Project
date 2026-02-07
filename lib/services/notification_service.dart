import 'dart:convert';
import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  /// Get all notifications for a specific user
  static Future<Map<String, dynamic>> getUserNotifications(String userId, {String? filter}) async {
    try {
      var endpoint = '/notifications/$userId';
      if (filter != null) {
        endpoint += '?filter=$filter';
      }
      
      final result = await ApiService.get(endpoint);
      
      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        if (data['success'] && data['data'] != null) {
          final notificationsList = data['data'] as List;
          final notifications = notificationsList
              .map((json) => Notification.fromJson(json))
              .toList();
              
          return {
            'success': true,
            'data': notifications,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch notifications',
          };
        }
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching notifications: $e',
      };
    }
  }

  /// Mark a specific notification as read
  static Future<Map<String, dynamic>> markAsRead(String notificationId, String userId) async {
    try {
      final result = await ApiService.put(
        '/notifications/$notificationId/read',
        data: {'userId': userId},
      );
      
      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Notification marked as read',
        };
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error marking notification as read: $e',
      };
    }
  }

  /// Mark all notifications as read for a user
  static Future<Map<String, dynamic>> markAllAsRead(String userId) async {
    try {
      final result = await ApiService.put(
        '/notifications/$userId/read-all',
        data: {},
      );
      
      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'All notifications marked as read',
        };
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error marking all notifications as read: $e',
      };
    }
  }

  /// Get unread notification count for a user (backend source of truth)
  static Future<int> getUnreadCount(String userId) async {
    try {
      final result = await ApiService.get('/notifications/$userId/unread-count');
      
      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        if (data['success'] && data['data'] != null) {
          final countData = data['data'] as Map<String, dynamic>;
          return countData['count'] as int? ?? 0;
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Get notification by ID
  static Future<Map<String, dynamic>> getNotificationById(String notificationId, String userId) async {
    try {
      final result = await ApiService.get('/notifications/$notificationId?userId=$userId');
      
      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        if (data['success'] && data['data'] != null) {
          final notification = Notification.fromJson(data['data']);
          return {
            'success': true,
            'data': notification,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch notification',
          };
        }
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching notification: $e',
      };
    }
  }
  
  /// Get unread notifications only
  static Future<Map<String, dynamic>> getUnreadNotifications(String userId) async {
    return await getUserNotifications(userId, filter: 'unread');
  }
  
  /// Legacy method for backward compatibility
  static Future<int> countUnreadNotifications(String userId) async {
    return await getUnreadCount(userId);
  }
}