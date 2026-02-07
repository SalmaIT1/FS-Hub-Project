import 'package:mysql_client/mysql_client.dart';
import 'database/db_connection.dart';

class NotificationService {
  // Create a new notification
  static Future<Map<String, dynamic>> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute(
        '''
        INSERT INTO notifications (user_id, title, message, type, timestamp, is_read) 
        VALUES (:userId, :title, :message, :type, :timestamp, :isRead)
        ''',
        {
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': false,
        },
      );
      
      // Get the inserted ID
      final selectResult = await conn.execute('SELECT LAST_INSERT_ID() as id');
      final insertedRow = selectResult.rows.first;
      final notificationId = insertedRow.colByName('id').toString();
      
      // Don't close the connection - let the connection manager handle it
      return {
        'success': true,
        'message': 'Notification created successfully',
        'data': {'id': notificationId}
      };
    } catch (e) {
      print('Error creating notification: $e');
      return {'success': false, 'message': 'Failed to create notification'};
    }
  }
  
  // Get all notifications for a user with optional filtering
  static Future<Map<String, dynamic>> getUserNotifications(String userId, {String? filter}) async {
    try {
      final conn = DBConnection.getConnection();
      
      String query = 'SELECT * FROM notifications WHERE user_id = :userId';
      final params = {'userId': userId};
      
      if (filter == 'unread') {
        query += ' AND is_read = FALSE';
      }
      
      query += ' ORDER BY timestamp DESC';
      
      final result = await conn.execute(query, params);
      
      final notifications = [];
      for (final row in result.rows) {
        notifications.add({
          'id': row.colByName('id'),
          'userId': row.colByName('user_id'),
          'title': row.colByName('title'),
          'message': row.colByName('message'),
          'type': row.colByName('type'),
          'timestamp': row.colByName('timestamp').toString(),
          'isRead': int.parse(row.colByName('is_read').toString()) == 1,
        });
      }
      
      // Don't close the connection - let the connection manager handle it
      return {'success': true, 'data': notifications};
    } catch (e) {
      print('Error fetching notifications: $e');
      return {'success': false, 'message': 'Failed to fetch notifications'};
    }
  }
  
  // Get count of unread notifications for a user
  static Future<Map<String, dynamic>> getUnreadNotificationCount(String userId) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute(
        '''
        SELECT COUNT(*) as count FROM notifications 
        WHERE user_id = :userId AND is_read = FALSE
        ''',
        {'userId': userId},
      );
      
      final row = result.rows.first;
      final count = int.parse(row.colByName('count').toString());
      
      // Don't close the connection - let the connection manager handle it
      return {'success': true, 'data': {'count': count}};
    } catch (e) {
      print('Error fetching unread notification count: $e');
      return {'success': false, 'message': 'Failed to fetch unread notification count'};
    }
  }
  
  // Mark a specific notification as read
  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId, String userId) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute(
        '''
        UPDATE notifications 
        SET is_read = TRUE 
        WHERE id = :notificationId AND user_id = :userId
        ''',
        {
          'notificationId': notificationId,
          'userId': userId,
        },
      );
      
      final affectedRows = result.affectedRows;
      
      // Don't close the connection - let the connection manager handle it
      // For idempotent operations, marking an already-read notification as read should succeed
      return {'success': true, 'message': 'Notification marked as read'};
    } catch (e) {
      print('Error marking notification as read: $e');
      return {'success': false, 'message': 'Failed to mark notification as read'};
    }
  }
  
  // Mark all notifications as read for a user
  static Future<Map<String, dynamic>> markAllNotificationsAsRead(String userId) async {
    try {
      final conn = DBConnection.getConnection();
      
      await conn.execute(
        '''
        UPDATE notifications 
        SET is_read = TRUE 
        WHERE user_id = :userId AND is_read = FALSE
        ''',
        {'userId': userId},
      );
      
      // Don't close the connection - let the connection manager handle it
      return {'success': true, 'message': 'All notifications marked as read'};
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return {'success': false, 'message': 'Failed to mark all notifications as read'};
    }
  }
  
  // Get notification by ID
  static Future<Map<String, dynamic>> getNotificationById(String notificationId, String userId) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute(
        '''
        SELECT * FROM notifications 
        WHERE id = :notificationId AND user_id = :userId
        ''',
        {
          'notificationId': notificationId,
          'userId': userId,
        },
      );
      
      if (result.rows.isEmpty) {
        return {'success': false, 'message': 'Notification not found'};
      }
      
      final row = result.rows.first;
      final notification = {
        'id': row.colByName('id'),
        'userId': row.colByName('user_id'),
        'title': row.colByName('title'),
        'message': row.colByName('message'),
        'type': row.colByName('type'),
        'timestamp': row.colByName('timestamp').toString(),
        'isRead': row.colByName('is_read') == 1,
      };
      
      // Don't close the connection - let the connection manager handle it
      return {'success': true, 'data': notification};
    } catch (e) {
      print('Error fetching notification: $e');
      return {'success': false, 'message': 'Failed to fetch notification'};
    }
  }
}