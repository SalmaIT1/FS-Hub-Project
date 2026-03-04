import '../../../../shared/database/connection.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final _db = DBConnection.getConnection();

  Future<String> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    return await _db.transaction((txn) async {
      await txn.execute(
        '''
        INSERT INTO notifications (user_id, title, message, type, timestamp, is_read) 
        VALUES (:userId, :title, :message, :type, NOW(), FALSE)
        ''',
        {
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
        },
      );
      final selectResult = await txn.execute('SELECT LAST_INSERT_ID() as id');
      return selectResult.rows.first.colByName('id').toString();
    });
  }

  Future<List<NotificationModel>> getUserNotifications(String userId, {String? filter}) async {
    String query = 'SELECT * FROM notifications WHERE user_id = :userId';
    final params = {'userId': userId};
    
    if (filter == 'unread') {
      query += ' AND is_read = FALSE';
    }
    query += ' ORDER BY timestamp DESC';
    
    final result = await _db.execute(query, params);
    return result.rows.map<NotificationModel>((row) => NotificationModel.fromMap(row.assoc())).toList();
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final result = await _db.execute(
      '''
      SELECT COUNT(*) as count FROM notifications 
      WHERE user_id = :userId AND is_read = FALSE
      ''',
      {'userId': userId},
    );
    return int.tryParse(result.rows.first.colByName('count').toString()) ?? 0;
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    await _db.execute(
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
  }

  Future<void> markAllAsRead(String userId) async {
    await _db.execute(
      '''
      UPDATE notifications 
      SET is_read = TRUE 
      WHERE user_id = :userId AND is_read = FALSE
      ''',
      {'userId': userId},
    );
  }

  Future<NotificationModel?> getNotificationById(String notificationId, String userId) async {
    final result = await _db.execute(
      '''
      SELECT * FROM notifications 
      WHERE id = :notificationId AND user_id = :userId
      ''',
      {
        'notificationId': notificationId,
        'userId': userId,
      },
    );
    if (result.rows.isEmpty) return null;
    return NotificationModel.fromMap(result.rows.first.assoc());
  }
}
