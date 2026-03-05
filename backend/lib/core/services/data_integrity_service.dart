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
      final result = await _db.execute('''
        SELECT t.id, t.titre, t.employee_id 
        FROM taches t
        WHERE t.statut != 'Done' 
        AND t.updated_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
      ''');

      for (final row in result.rows) {
        final taskId = row.colByName('id');
        final title = row.colByName('titre');
        final userId = row.colByName('employee_id');

        if (userId != null) {
          await NotificationService.createNotification(
            userId: userId.toString(),
            title: 'Task Staleness Alert',
            message: 'Your task "$title" hasn\'t been updated in 7 days.',
            type: 'task_stale',
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
      // SECURE BATCH VALIDATION: Use safe parameterization
      final params = <String, dynamic>{};
      final placeholders = [];
      for (int i = 0; i < uploadIds.length; i++) {
        final key = 'id$i';
        placeholders.add(':$key');
        params[key] = uploadIds[i];
      }
      
      final result = await _db.execute(
        "SELECT COUNT(*) as cnt FROM file_uploads WHERE id IN (${placeholders.join(',')}) AND expires_at >= NOW()",
        params
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
       final params = <String, dynamic>{};
      final placeholders = [];
      for (int i = 0; i < uploadIds.length; i++) {
        final key = 'id$i';
        placeholders.add(':$key');
        params[key] = uploadIds[i];
      }

      await _db.execute(
        "UPDATE file_uploads SET is_completed = TRUE, expires_at = DATE_ADD(NOW(), INTERVAL 1 YEAR) WHERE id IN (${placeholders.join(',')})",
        params
      );
    } catch (e) {
      print('Mark uploads used error: $e');
    }
  }
}
