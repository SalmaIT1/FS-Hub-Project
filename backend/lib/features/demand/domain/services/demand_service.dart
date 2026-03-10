import 'package:bcrypt/bcrypt.dart';
import 'dart:math';
import '../../data/repositories/demand_repository.dart';
import '../../../notification/domain/services/notification_service.dart';
import '../../../../shared/services/audit_service.dart';

const Set<String> _allowedDemandTypes = {
  'password_reset', 'hardware', 'administrative', 'custom', 'other',
};

const Set<String> _allowedDemandStatuses = {
  'pending', 'in_progress', 'resolved', 'rejected',
};

class DemandService {
  static final _repository = DemandRepository();

  static Future<Map<String, dynamic>> createDemand(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    if (type == null || !_allowedDemandTypes.contains(type)) {
      return {'success': false, 'message': 'Invalid demand type'};
    }

    final requesterId = data['requesterId']?.toString();
    if (requesterId == null) return {'success': false, 'message': 'requesterId is required'};

    final id = await _repository.createDemand({
      'type': type,
      'description': data['description']?.toString() ?? '',
      'requesterId': requesterId,
    });

    await _notifyAdmins('New Demand', 'A new $type demand was submitted.', 'demand_created');
    await AuditService.log(requesterId, 'DEMAND_CREATED', {'demandId': id, 'type': type});

    return {'success': true, 'message': 'Demand created', 'data': {'demandId': id.toString()}};
  }

  static Future<Map<String, dynamic>> getAllDemands({
    String? type,
    String? status,
    String? requesterId,
    String? userRole,
    String? callerId,
  }) async {
    try {
      final isAdmin = userRole == 'Admin' || userRole == 'RH' || userRole == 'Manager';
      final demands = await _repository.getAllDemands(
        type: type,
        status: status,
        requesterId: isAdmin ? requesterId : callerId,
        isAdmin: isAdmin,
      );
      return {'success': true, 'data': demands.map((d) => d.toJson()).toList()};
    } catch (e, stack) {
      print('❌ [DemandService] Error in getAllDemands: $e\n$stack');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getDemandById(String id) async {
    final demand = await _repository.getDemandById(id);
    if (demand == null) return {'success': false, 'message': 'Demand not found'};
    return {'success': true, 'data': demand.toJson()};
  }

  static Future<Map<String, dynamic>> updateDemandSecurely(
    String id,
    Map<String, dynamic> data,
    String currentUserId,
    String currentUserRole,
  ) async {
    final demand = await _repository.getDemandById(id);
    if (demand == null) return {'success': false, 'message': 'Demand not found'};

    if (currentUserRole != 'Admin' && demand.requesterId != currentUserId) {
      return {'success': false, 'message': 'Permission denied'};
    }

    await _repository.updateDescription(id, data['description'] ?? '');
    return {'success': true, 'message': 'Demand updated'};
  }

  static Future<Map<String, dynamic>> updateDemandStatus(
    String id,
    Map<String, dynamic> data,
    String currentUserId,
    String currentUserRole,
  ) async {
    if (currentUserRole != 'Admin' && currentUserRole != 'RH' && currentUserRole != 'Manager') {
      return {'success': false, 'message': 'Permission denied: Manager, RH or Admin role required'};
    }

    final demand = await _repository.getDemandById(id);
    if (demand == null) return {'success': false, 'message': 'Demand not found'};

    // Guard: Admin/RH/Manager cannot approve their own demand (Audit integrity)
    if (demand.requesterId == currentUserId && currentUserRole != 'Admin') {
      return {'success': false, 'message': 'You cannot resolve your own demand for audit purposes.'};
    }

    final status = data['status']?.toString();
    if (status == null || !_allowedDemandStatuses.contains(status)) {
      return {'success': false, 'message': 'Invalid status'};
    }

    await _repository.updateStatus(id, status, currentUserId, data['resolution_notes'] ?? '');
    await AuditService.log(currentUserId, 'DEMAND_STATUS_CHANGED', {'demandId': id, 'newStatus': status});

    // Notify requester
    await NotificationService.createNotification(
      userId: demand.requesterId,
      title: 'Demand Status Updated',
      message: 'Your demand ($id) has been $status.',
      type: 'demand_status_updated',
    );

    if (status == 'resolved' && demand.type == 'password_reset') {
      return await handlePasswordResetDemand(id, currentUserId);
    }

    return {'success': true, 'message': 'Status updated'};
  }

  static Future<Map<String, dynamic>> deleteDemand(String id, String currentUserId, String? currentUserRole) async {
    final demand = await _repository.getDemandById(id);
    if (demand == null) return {'success': false, 'message': 'Demand not found'};

    if (currentUserRole != 'Admin' && demand.requesterId != currentUserId) {
      return {'success': false, 'message': 'Permission denied'};
    }

    await _repository.deleteDemand(id);
    return {'success': true, 'message': 'Demand deleted'};
  }

  static Future<Map<String, dynamic>> handlePasswordResetDemand(String demandId, String handledByUserId) async {
    final demand = await _repository.getDemandById(demandId);
    if (demand == null) return {'success': false, 'message': 'Demand not found'};

    final tempPassword = _generateTempPassword();
    final hashedPassword = BCrypt.hashpw(tempPassword, BCrypt.gensalt());

    await _repository.updateUserPassword(demand.requesterId, hashedPassword);
    await _repository.updateStatus(demandId, 'resolved', handledByUserId, 'Password reset automatically');
    
    await NotificationService.createNotification(
      userId: demand.requesterId,
      title: 'Password Reset Completed',
      message: 'Your temporary password has been set. Please contact your administrator to receive it securely.',
      type: 'password_reset',
    );

    return {'success': true, 'message': 'Password reset', 'temp_password': tempPassword};
  }

  static Future<void> _notifyAdmins(String title, String message, String type) async {
    final adminIds = await _repository.getAdminIds();
    for (final adminId in adminIds) {
      await NotificationService.createNotification(
        userId: adminId,
        title: title,
        message: message,
        type: type,
      );
    }
  }

  static String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
    final rand = Random();
    return List.generate(12, (index) => chars[rand.nextInt(chars.length)]).join();
  }
}
