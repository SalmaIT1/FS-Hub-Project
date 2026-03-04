import 'dart:convert';
import '../../../../shared/database/connection.dart';
import '../models/demand_model.dart';

class DemandRepository {
  final _db = DBConnection.getConnection();

  Future<int> createDemand(Map<String, dynamic> data) async {
    return await _db.transaction((tx) async {
      final insertResult = await tx.execute('''
        INSERT INTO demands (type, description, status, requester_id, created_at, updated_at)
        VALUES (:type, :description, 'pending', :requesterId, NOW(), NOW())
      ''', {
        'type': data['type'],
        'description': data['description'],
        'requesterId': data['requesterId'],
      });
      return insertResult.lastInsertID.toInt();
    });
  }

  Future<List<DemandModel>> getAllDemands({
    String? type,
    String? status,
    String? requesterId,
    bool isAdmin = false,
  }) async {
    String query = '''
      SELECT d.id, d.type, d.description, d.status, d.requester_id,
             d.handled_by, d.resolution_notes, d.created_at, d.updated_at,
             u.username as requester_name
      FROM demands d
      LEFT JOIN users u ON d.requester_id = u.id
      WHERE 1=1
    ''';
    final params = <String, dynamic>{};

    if (!isAdmin && requesterId != null) {
      query += ' AND d.requester_id = :requesterId';
      params['requesterId'] = requesterId;
    }
    if (type != null && type.isNotEmpty) {
      query += ' AND d.type = :type';
      params['type'] = type;
    }
    if (status != null && status.isNotEmpty) {
      query += ' AND d.status = :status';
      params['status'] = status;
    }

    query += ' ORDER BY d.created_at DESC';

    final result = await _db.execute(query, params);
    return result.rows.map<DemandModel>((row) => DemandModel.fromMap(row.assoc())).toList();
  }

  Future<DemandModel?> getDemandById(String id) async {
    final result = await _db.execute('''
      SELECT d.id, d.type, d.description, d.status, d.requester_id,
             d.handled_by, d.resolution_notes, d.created_at, d.updated_at,
             u.username as requester_name
      FROM demands d
      LEFT JOIN users u ON d.requester_id = u.id
      WHERE d.id = :id
    ''', {'id': id});

    if (result.rows.isEmpty) return null;
    return DemandModel.fromMap(result.rows.first.assoc());
  }

  Future<void> updateDescription(String id, String description) async {
    await _db.execute('''
      UPDATE demands SET description = :description, updated_at = NOW()
      WHERE id = :id
    ''', {
      'description': description,
      'id': id,
    });
  }

  Future<void> updateStatus(String id, String status, String handledBy, String resolutionNotes) async {
    await _db.execute('''
      UPDATE demands
      SET status = :status, handled_by = :handledBy,
          resolution_notes = :resolutionNotes, updated_at = NOW()
      WHERE id = :id
    ''', {
      'status': status,
      'handledBy': handledBy,
      'resolutionNotes': resolutionNotes,
      'id': id,
    });
  }

  Future<void> deleteDemand(String id) async {
    await _db.execute('DELETE FROM demands WHERE id = :id', {'id': id});
  }

  Future<void> updateUserPassword(String userId, String hashedPassword) async {
    await _db.execute(
      'UPDATE users SET password = :password WHERE id = :userId',
      {'password': hashedPassword, 'userId': userId},
    );
  }

  Future<void> auditLog(String userId, String action, Map<String, dynamic> details) async {
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
      print('Audit log warning: $e');
    }
  }

  Future<List<String>> getAdminIds() async {
    final result = await _db.execute("SELECT id FROM users WHERE role = 'Admin'");
    return result.rows.map((row) => row.colByName('id').toString()).toList();
  }
}
