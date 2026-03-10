import 'dart:convert';
import '../database/connection.dart';

class AuditService {
  static final _db = DBConnection.getConnection();

  static Future<void> log(String userId, String action, Map<String, dynamic> details) async {
    try {
      await _db.execute('''
        INSERT INTO audit_log (user_id, action, details, created_at)
        VALUES (:userId, :action, :details, NOW())
      ''', {
        'userId': userId,
        'action': action,
        'details': jsonEncode(details),
      });
    } catch (e) {
      print('❌ [AuditService] Error logging action "$action": $e');
    }
  }
}
