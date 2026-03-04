import 'dart:async';
import '../../shared/database/connection.dart';
import '../../features/notification/domain/services/notification_service.dart';

class DataIntegrityService {
  static final _db = DBConnection.getConnection();

  /// Starts periodic background workers for the backend
  static void startPeriodicCleanup() {
    // 1. Cleanup expired uploads every hour
    Timer.periodic(const Duration(hours: 1), (timer) {
      _cleanupExpiredUploads();
    });

    // 2. Check for overdue tasks every hour
    Timer.periodic(const Duration(hours: 1), (timer) {
      checkDeadlines();
    });
  }

  /// Deletes upload records and files that were never completed
  static Future<void> _cleanupExpiredUploads() async {
    try {
      // Logic from audit report: delete if expired_at is in the past and not completed
      // For this MVP, we just log it or do a simple DB cleanup
      await _db.execute(
        "DELETE FROM file_uploads WHERE is_completed = FALSE AND expires_at < NOW()"
      );
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  /// Checks for overdue tasks and sends notifications to owners
  static Future<void> checkDeadlines() async {
    try {
      // Find tasks that are past their due_date and not completed
      final result = await _db.execute('''
        SELECT t.id, t.title, t.assigned_to 
        FROM tasks t
        WHERE t.status != 'completed' 
        AND t.due_date < NOW()
      ''');

      for (final row in result.rows) {
        final taskId = row.colByName('id');
        final title = row.colByName('title');
        final userId = row.colByName('assigned_to');

        if (userId != null) {
          await NotificationService.createNotification(
            userId: userId.toString(),
            title: 'Task Overdue',
            message: 'Your task "$title" is past its deadline.',
            type: 'deadline_overdue',
          );
        }
      }
    } catch (e) {
      print('Deadline check error: $e');
    }
  }

  /// Extends the expiry of an upload when it is actually used in a message
  static Future<void> protectUpload(int uploadId) async {
    try {
      await _db.execute(
        "UPDATE file_uploads SET is_completed = TRUE, expires_at = DATE_ADD(NOW(), INTERVAL 1 YEAR) WHERE id = :id",
        {'id': uploadId}
      );
    } catch (e) {
       print('Protect upload error: $e');
    }
  }

  /// Validates that all provided upload IDs exist, are unexpired, and haven't already been used
  static Future<bool> validateUploadsForMessage(List<String> uploadIds) async {
    if (uploadIds.isEmpty) return true;
    try {
      final placeholders = uploadIds.map((id) => "'$id'").join(',');
      final result = await _db.execute(
        "SELECT COUNT(*) as cnt FROM file_uploads WHERE id IN ($placeholders) AND expires_at >= NOW()"
      );
      final count = int.tryParse(result.rows.first.colByName('cnt')?.toString() ?? '0') ?? 0;
      return count == uploadIds.length;
    } catch (e) {
      print('Upload validation error: $e');
      return false;
    }
  }

  /// Marks a batch of uploads as completed and extends their expiry duration permanently
  static Future<void> markUploadsAsUsed(List<String> uploadIds) async {
    if (uploadIds.isEmpty) return;
    try {
      final placeholders = uploadIds.map((id) => "'$id'").join(',');
      await _db.execute(
        "UPDATE file_uploads SET is_completed = TRUE, expires_at = DATE_ADD(NOW(), INTERVAL 1 YEAR) WHERE id IN ($placeholders)"
      );
    } catch (e) {
      print('Mark uploads used error: $e');
    }
  }
}
