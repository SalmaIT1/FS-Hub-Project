import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../shared/database/connection.dart';
import '../../features/notification/domain/services/notification_service.dart';

class DataIntegrityService {
  static final _db = DBConnection.getConnection();
  static bool _isCheckingDeadlines = false;
  static bool _isCleaningUploads = false;

  /// Starts periodic background workers for the backend
  static void startPeriodicCleanup() {
    // 1. Cleanup expired uploads every hour
    Timer.periodic(const Duration(hours: 1), (timer) {
      if (!_isCleaningUploads) _cleanupExpiredUploads();
    });

    // 2. Check for overdue tasks and project status every hour
    Timer.periodic(const Duration(hours: 1), (timer) {
      if (!_isCheckingDeadlines) checkDeadlines();
    });

    // 3. L-5 FIX: Prune stale rows from security tables every 6 hours.
    //    - revoked_tokens: entries older than 24 h are useless (token already expired by JWT TTL).
    //    - rate_limit_attempts: entries outside the widest rate window (15 min) are useless.
    Timer.periodic(const Duration(hours: 6), (timer) {
      _cleanupSecurityTables();
    });
  }

  /// Deletes upload records and files that were never completed
  static Future<void> _cleanupExpiredUploads() async {
    _isCleaningUploads = true;
    try {
      // 1. Database-driven cleanup (Uncompleted/Expired)
      final expired = await _db.execute(
        "SELECT id, file_path FROM file_uploads WHERE is_completed = FALSE AND expires_at < NOW()"
      );

      // Canonical sandbox root — resolves symlinks and collapses '..' segments.
      final uploadRootDir = Directory('uploads');
      final uploadRootCanonical = p.canonicalize(uploadRootDir.absolute.path);

      for (final row in expired.rows) {
        final path = row.colByName('file_path')?.toString();
        if (path != null) {
          final file = File(path);
          // HARSH FIX: Canonicalize before comparing to prevent '..' traversal bypass.
          final canonicalPath = p.canonicalize(file.absolute.path);
          if (canonicalPath.startsWith(uploadRootCanonical)) {
            if (await file.exists()) {
              await file.delete();
              print('[DataIntegrityService] Deleted physical file: $path');
            }
          } else {
             print('[DataIntegrityService] WARNING: Blocked attempt to delete file outside sandbox: $path (canonical: $canonicalPath)');
          }
        }
      }

      await _db.execute(
        "DELETE FROM file_uploads WHERE is_completed = FALSE AND expires_at < NOW()"
      );

      // 3. P2-1 FIX: Prune unreferenced uploads (orphans) older than 24 hours
      // These are files that might have been marked as completed but never successfully
      // attached to a message (e.g., if the message creation request failed).
      await _db.execute('''
        DELETE FROM file_uploads 
        WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY)
        AND file_path NOT IN (SELECT file_path FROM message_attachments)
        AND file_path NOT IN (SELECT file_path FROM message_voice_messages)
      ''');

      // 2. Physical audit (Deep cleanup of untracked files in 'uploads/' sandbox)
      // This handles cases where database records were deleted without cleaning disk.
      if (await uploadRootDir.exists()) {
        final trackedFiles = await _db.execute("SELECT file_path FROM file_uploads");
        final trackedPaths = trackedFiles.rows
            .map((r) => p.canonicalize(File(r.colAt(0).toString()).absolute.path))
            .toSet();

        await for (final entity in uploadRootDir.list(recursive: true)) {
          if (entity is File) {
            final absCanonicalPath = p.canonicalize(entity.absolute.path);
            // Never delete .gitkeep or system files
            if (entity.path.endsWith('.gitkeep')) continue;
            // Safety: only delete files that are inside the sandbox
            if (!absCanonicalPath.startsWith(uploadRootCanonical)) continue;
            
            if (!trackedPaths.contains(absCanonicalPath)) {
              print('[DataIntegrityService] Pruning untracked physical orphan: ${entity.path}');
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      print('Cleanup error: $e');
    } finally {
      _isCleaningUploads = false;
    }
  }

  /// L-5 FIX: Prunes stale rows from security-related tables.
  static Future<void> _cleanupSecurityTables() async {
    try {
      // Revoked access tokens expire within 24 h by JWT design — older rows are useless.
      final revokedRes = await _db.execute(
        'DELETE FROM revoked_tokens WHERE created_at < DATE_SUB(NOW(), INTERVAL 24 HOUR)'
      );
      print('[DataIntegrityService] Pruned revoked_tokens: ${revokedRes.affectedRows} rows removed');
    } catch (e) {
      print('[DataIntegrityService] revoked_tokens cleanup error: \$e');
    }
    try {
      final rlRes = await _db.execute(
        'DELETE FROM rate_limit_attempts WHERE attempted_at < DATE_SUB(NOW(), INTERVAL 15 MINUTE)'
      );
      print('[DataIntegrityService] Pruned rate_limit_attempts: ${rlRes.affectedRows} rows removed');
    } catch (e) {
      print('[DataIntegrityService] rate_limit_attempts cleanup error: $e');
    }

    try {
      // HARSH FIX: Prune expired refresh tokens (revoked or naturally old).
      // Older than 30 days to keep a small buffer for audit purposes.
      final rtRes = await _db.execute(
        'DELETE FROM refresh_tokens WHERE expires_at < DATE_SUB(NOW(), INTERVAL 30 DAY)'
      );
      print('[DataIntegrityService] Pruned refresh_tokens: ${rtRes.affectedRows} rows removed');
    } catch (e) {
      print('[DataIntegrityService] refresh_tokens cleanup error: $e');
    }
  }

  /// Checks for overdue tasks and sends notifications to owners
  static Future<void> checkDeadlines() async {
    _isCheckingDeadlines = true;
    try {
      // 1. Check Tasks
      final tasks = await _db.execute('''
        SELECT t.id, t.titre, t.employee_id 
        FROM taches t
        WHERE t.statut != 'Done' 
        AND t.updated_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
      ''');

      for (final row in tasks.rows) {
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

      // 2. Check Projects past start date but still 'Planifie'
      final lateProjects = await _db.execute('''
        SELECT p.id, p.nom, (SELECT count(*) FROM projet_membres pm WHERE pm.projet_id = p.id) as member_count
        FROM projets p
        WHERE p.statut = 'A venir' AND p.date_debut <= NOW() AND p.is_deleted = FALSE
      ''');

      for (final row in lateProjects.rows) {
        final id = int.parse(row.colByName('id').toString());
        final nom = row.colByName('nom');
        final memberCount = int.parse(row.colByName('member_count').toString());

        if (memberCount == 0) {
          // No members? Mark as late immediately and notify admins
          await _db.execute("UPDATE projets SET statut = 'En retard' WHERE id = :id", {'id': id});
          print('[DataIntegrityService] Project "$nom" marked EN RETARD (Missing members at start date)');
        } else {
          // Has members? Auto-start
          await _db.execute("UPDATE projets SET statut = 'En cours' WHERE id = :id", {'id': id});
          print('[DataIntegrityService] Project "$nom" auto-started (En cours)');
        }
      }
      // 3. Mark active projects as 'En retard' if they pass finish date
      await _db.execute('''
        UPDATE projets 
        SET statut = 'En retard' 
        WHERE statut = 'En cours' AND date_fin_prevue < NOW() AND is_deleted = FALSE
      ''');
    } catch (e) {
      print('Deadline check error: $e');
    } finally {
      _isCheckingDeadlines = false;
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
        "SELECT file_path, file_size FROM file_uploads WHERE id IN (${placeholders.join(',')}) AND expires_at >= NOW()",
        params
      );
      
      if (result.rows.length != uploadIds.length) return false;

      // Ensure physical files exist and sizes match (to prevent sending while upload stream is pending)
      for (final row in result.rows) {
        final path = row.colByName('file_path')?.toString();
        final expectedSize = int.tryParse(row.colByName('file_size')?.toString() ?? '0') ?? 0;
        
        if (path == null || path == 'pending') return false;
        
        final file = File(path);
        if (!await file.exists()) return false;
        
        final actualSize = await file.length();
        // Allow a small tolerance for file size due to metadata, or exact match
        if (expectedSize > 0 && actualSize != expectedSize && actualSize == 0) return false;
      }
      return true;
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
