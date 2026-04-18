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

  static Future<List<Map<String, dynamic>>> getLogs({
    int limit = 100,
    String? action,
    String? userId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      String query = '''
        SELECT a.*, u.username as user_name, u.username as user_email
        FROM audit_log a
        LEFT JOIN users u ON a.user_id = u.id
        WHERE 1=1
      ''';
      final params = <String, dynamic>{'limit': limit};

      if (action != null && action.isNotEmpty) {
        query += ' AND a.action = :action';
        params['action'] = action;
      }
      if (userId != null && userId.isNotEmpty) {
        query += ' AND a.user_id = :userId';
        params['userId'] = userId;
      }
      if (startDate != null && startDate.isNotEmpty) {
        query += ' AND a.created_at >= :startDate';
        params['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        query += ' AND a.created_at <= :endDate';
        params['endDate'] = endDate;
      }

      query += ' ORDER BY a.created_at DESC LIMIT :limit';
      
      final res = await _db.execute(query, params);
      return res.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      print('❌ [AuditService] Error fetching logs: $e');
      return [];
    }
  }
}
