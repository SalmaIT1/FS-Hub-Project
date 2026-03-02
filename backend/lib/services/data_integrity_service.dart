import 'dart:async';
import 'dart:io';
import '../database/db_connection.dart';

/// Data integrity service for attachment and message consistency
/// 
/// Responsibilities:
/// - Clean up orphaned uploads
/// - Validate message-attachment relationships
/// - Enforce data consistency rules
/// - Periodic maintenance tasks
class DataIntegrityService {
  static Timer? _cleanupTimer;
  
  /// Start periodic cleanup tasks
  static void startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(hours: 1), (_) {
      _performCleanup();
    });
  }
  
  /// Stop periodic cleanup
  static void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
  
  /// Perform comprehensive cleanup and validation
  static Future<void> _performCleanup() async {
    try {
      print('[INTEGRITY] Starting periodic tasks...');
      
      await _cleanupExpiredUploads();
      await _validateMessageAttachments();
      await _cleanupOrphanedAttachments();
      await checkDeadlines();
      await _checkOverdueTasks();
      
      print('[INTEGRITY] Periodic tasks completed');
    } catch (e) {
      print('[INTEGRITY] Periodic tasks failed: $e');
    }
  }

  /// Check for tasks that are past their deadline or have exceeded effort
  static Future<void> _checkOverdueTasks() async {
    final conn = DBConnection.getConnection();
    
    try {
      // Find tasks in sprints that have passed their end date but are NOT 'Done'
      final overdueTasks = await conn.execute('''
        SELECT t.id, t.titre, t.employee_id, s.nom as sprint_nom, p.nom as project_nom
        FROM taches t
        JOIN sprints s ON t.sprint_id = s.id
        JOIN projets p ON s.projet_id = p.id
        WHERE s.date_fin < CURDATE()
        AND t.statut != 'Done'
      ''');

      for (final row in overdueTasks.rows) {
        final taskTitle = row.colByName('titre');
        final employeeId = row.colByName('employee_id');
        final sprintName = row.colByName('sprint_nom');
        final projectNom = row.colByName('project_nom');

        if (employeeId != null) {
          await conn.execute('''
            INSERT INTO notifications (user_id, title, message, type, timestamp, is_read)
            VALUES (:uid, :title, :msg, :type, :ts, :read)
          ''', {
            'uid': employeeId,
            'title': 'Tâche en retard',
            'msg': 'La tâche "$taskTitle" du sprint $sprintName ($projectNom) est en retard.',
            'type': 'task_overdue',
            'ts': DateTime.now().toIso8601String(),
            'read': 0
          });
        }
      }
    } catch (e) {
      print('[INTEGRITY] Overdue task check failed: $e');
    }
  }

  /// Check for upcoming project and sprint deadlines
  static Future<void> checkDeadlines() async {
    final conn = DBConnection.getConnection();
    
    try {
      // 1. Check Projects due in 3 days
      final projects = await conn.execute('''
        SELECT id, nom, date_fin_prevue 
        FROM projets 
        WHERE date_fin_prevue = DATE_ADD(CURDATE(), INTERVAL 3 DAY)
        AND statut != 'Terminé'
      ''');

      for (final row in projects.rows) {
        final projectId = row.colByName('id');
        final projectName = row.colByName('nom');
        
        await _notifyProjectStakeholders(
          projectId!, 
          'Échéance du projet proche', 
          'Le projet "$projectName" se termine dans 3 jours.',
          'deadline_warning'
        );
      }

      // 2. Check Sprints due in 3 days
      final sprints = await conn.execute('''
        SELECT s.id, s.nom, s.projet_id, p.nom as project_nom
        FROM sprints s
        JOIN projets p ON s.projet_id = p.id
        WHERE s.date_fin = DATE_ADD(CURDATE(), INTERVAL 3 DAY)
      ''');

      for (final row in sprints.rows) {
        final sprintId = row.colByName('id');
        final sprintName = row.colByName('nom');
        final projectId = row.colByName('projet_id');
        final projectNom = row.colByName('project_nom');
        
        await _notifyProjectStakeholders(
          projectId!,
          'Échéance de Sprint proche',
          'Le sprint "$sprintName" ($projectNom) se termine dans 3 jours.',
          'sprint_warning'
        );
      }
    } catch (e) {
      print('[INTEGRITY] Deadline check failed: $e');
    }
  }

  static Future<void> _notifyProjectStakeholders(String projectId, String title, String message, String type) async {
    final conn = DBConnection.getConnection();
    
    // Get project members
    final members = await conn.execute(
      'SELECT employee_id FROM projet_membres WHERE projet_id = :pid', 
      {'pid': projectId}
    );

    // Get admins
    final admins = await conn.execute("SELECT id FROM employees WHERE role = 'Admin'");

    final recipientIds = <String>{};
    for (var r in members.rows) recipientIds.add(r.colByName('employee_id')!);
    for (var r in admins.rows) recipientIds.add(r.colByName('id')!);

    for (var userId in recipientIds) {
      // Import NotificationService at top or use fully qualified name
      // To avoid circular dependency if any, we'll assume it's available
      // or we can direct insert
      await conn.execute('''
        INSERT INTO notifications (user_id, title, message, type, timestamp, is_read)
        VALUES (:uid, :title, :msg, :type, :ts, :read)
      ''', {
        'uid': userId,
        'title': title,
        'msg': message,
        'type': type,
        'ts': DateTime.now().toIso8601String(),
        'read': 0
      });
    }
  }
  
  /// Clean up expired uploads that were never used in messages
  static Future<void> _cleanupExpiredUploads() async {
    final conn = DBConnection.getConnection();
    
    // Find uploads that are expired and not attached to any message
    final result = await conn.execute('''
      SELECT fu.id, fu.file_path, fu.stored_filename
      FROM file_uploads fu
      LEFT JOIN message_attachments ma ON fu.id = ma.upload_id
      WHERE fu.expires_at < NOW()
      AND ma.id IS NULL
    ''');

    int cleanedCount = 0;
    for (final row in result.rows) {
        try {
        final uploadId = row.colByName('id');
        final filePath = row.colByName('file_path');
        
        // Delete physical file
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        
        // Delete database record
        await conn.execute('DELETE FROM file_uploads WHERE id = :id', {'id': uploadId});
        
        cleanedCount++;
      } catch (e) {
        print('[INTEGRITY] Failed to cleanup upload ${row.colByName('id')}: $e');
      }
    }
    
    if (cleanedCount > 0) {
      print('[INTEGRITY] Cleaned up $cleanedCount expired uploads');
    }
  }
  
  /// Validate that all message attachments have corresponding uploads
  static Future<void> _validateMessageAttachments() async {
    final conn = DBConnection.getConnection();
    
    // Find attachments pointing to non-existent uploads
    final orphanedAttachments = await conn.execute('''
      SELECT ma.id, ma.message_id, ma.file_path
      FROM message_attachments ma
      LEFT JOIN file_uploads fu ON ma.filename = fu.stored_filename
      WHERE fu.id IS NULL
    ''');
    
    int fixedCount = 0;
    for (final row in orphanedAttachments.rows) {
      try {
        final attachmentId = row.colByName('id');
        final messageId = row.colByName('message_id');
        
        // Remove orphaned attachment
        await conn.execute('DELETE FROM message_attachments WHERE id = :id', {'id': attachmentId});
        
        fixedCount++;
        print('[INTEGRITY] Removed orphaned attachment $attachmentId from message $messageId');
      } catch (e) {
        print('[INTEGRITY] Failed to remove orphaned attachment: $e');
      }
    }
    
    if (fixedCount > 0) {
      print('[INTEGRITY] Fixed $fixedCount orphaned attachments');
    }
  }
  
  /// Clean up attachments for messages that don't exist
  static Future<void> _cleanupOrphanedAttachments() async {
    final conn = DBConnection.getConnection();
    
    // Find attachments pointing to non-existent messages
    final orphanedAttachments = await conn.execute('''
      SELECT ma.id, ma.message_id, ma.file_path
      FROM message_attachments ma
      LEFT JOIN messages m ON ma.message_id = m.id
      WHERE m.id IS NULL
    ''');
    
    int cleanedCount = 0;
    for (final row in orphanedAttachments.rows) {
      try {
        final attachmentId = row.colByName('id');
        final messageId = row.colByName('message_id');
        final filePath = row.colByName('file_path');
        
        // Delete physical file
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        
        // Delete database record
        await conn.execute('DELETE FROM message_attachments WHERE id = :id', {'id': attachmentId});
        
        cleanedCount++;
        print('[INTEGRITY] Cleaned up attachment $attachmentId for non-existent message $messageId');
      } catch (e) {
        print('[INTEGRITY] Failed to cleanup orphaned attachment: $e');
      }
    }
    
    if (cleanedCount > 0) {
      print('[INTEGRITY] Cleaned up $cleanedCount orphaned attachments');
    }
  }
  
  /// Validate attachment before message creation
  static Future<bool> validateUploadsForMessage(List<String> uploadIds) async {
    if (uploadIds.isEmpty) return true;
    
    final conn = DBConnection.getConnection();
    
    // Check if all uploads exist and are not expired
    // Build named placeholders for IN clause
    final placeholders = List.generate(uploadIds.length, (i) => ':p$i').join(',');
    final params = <String, dynamic>{};
    for (var i = 0; i < uploadIds.length; i++) {
      params['p$i'] = uploadIds[i];
    }

    final result = await conn.execute('''
      SELECT COUNT(*) as count
      FROM file_uploads
      WHERE id IN ($placeholders)
      AND expires_at > NOW()
    ''', params);

    final count = int.tryParse(result.rows.first.colByName('count').toString()) ?? 0;
    return count == uploadIds.length;
  }
  
  /// Mark uploads as used by a message
  static Future<void> markUploadsAsUsed(List<String> uploadIds) async {
    if (uploadIds.isEmpty) return;
    
    final conn = DBConnection.getConnection();
    // Build named placeholders for IN clause
    final placeholders = List.generate(uploadIds.length, (i) => ':p$i').join(',');
    final params = <String, dynamic>{};
    for (var i = 0; i < uploadIds.length; i++) params['p$i'] = uploadIds[i];

    // Update expires_at to far future to prevent cleanup
    await conn.execute('''
      UPDATE file_uploads
      SET expires_at = DATE_ADD(NOW(), INTERVAL 1 YEAR)
      WHERE id IN ($placeholders)
    ''', params);
  }
  
  /// Get statistics about data integrity
  static Future<Map<String, dynamic>> getIntegrityStats() async {
    final conn = DBConnection.getConnection();
    
    final stats = <String, dynamic>{};
    
    // Count expired uploads
    final expiredUploads = await conn.execute('''
      SELECT COUNT(*) as count FROM file_uploads WHERE expires_at < NOW()
    ''');
    stats['expired_uploads'] = int.tryParse(expiredUploads.rows.first.colByName('count').toString()) ?? 0;
    
    // Count orphaned attachments
    final orphanedAttachments = await conn.execute('''
      SELECT COUNT(*) as count 
      FROM message_attachments ma
      LEFT JOIN messages m ON ma.message_id = m.id
      WHERE m.id IS NULL
    ''');
    stats['orphaned_attachments'] = int.tryParse(orphanedAttachments.rows.first.colByName('count').toString()) ?? 0;
    
    // Count total uploads and attachments
    final totalUploads = await conn.execute('SELECT COUNT(*) as count FROM file_uploads');
    stats['total_uploads'] = int.tryParse(totalUploads.rows.first.colByName('count').toString()) ?? 0;
    
    final totalAttachments = await conn.execute('SELECT COUNT(*) as count FROM message_attachments');
    stats['total_attachments'] = int.tryParse(totalAttachments.rows.first.colByName('count').toString()) ?? 0;
    
    return stats;
  }
}
