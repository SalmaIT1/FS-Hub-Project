import 'dart:math' as math;
import 'package:mysql_client/mysql_client.dart';
import 'database/db_connection.dart';

class DemandService {
  // Create a new demand
  static Future<Map<String, dynamic>> createDemand(Map<String, dynamic> data) async {
    try {
      final conn = DBConnection.getConnection();

      // Insert the demand
      final result = await conn.execute(
        '''
        INSERT INTO demands (type, description, requester_id, status, created_at) 
        VALUES (:type, :description, :requesterId, :status, :createdAt)
        ''',
        {
          'type': data['type'],
          'description': data['description'],
          'requesterId': data['requesterId'],
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      // Get the inserted ID using a separate query since lastInsertId might not be available
      final selectResult = await conn.execute(
        'SELECT LAST_INSERT_ID() as id'
      );
      final insertedRow = selectResult.rows.first;
      final demandId = insertedRow.colByName('id').toString();

      // Create notification for admins about the new demand
      await _createDemandNotification(demandId, data['type'], data['requesterId']);
      
      // Log audit event
      await logAuditEvent(data['requesterId'], 'CREATE_DEMAND', 'Created new ${data['type']} demand with ID: $demandId');

      // Don't close the connection - let the connection manager handle it
      
      return {
        'success': true,
        'message': 'Demand created successfully',
        'data': {'id': demandId}
      };
    } catch (e) {
      print('Error creating demand: $e');
      return {'success': false, 'message': 'Failed to create demand'};
    }
  }

  // Get all demands with optional filtering
  static Future<Map<String, dynamic>> getAllDemands({String? type, String? status}) async {
    try {
      final conn = DBConnection.getConnection();
      
      String query = '''
        SELECT d.*, 
               e.nom as requester_name,
               e.prenom as requester_first_name,
               admin_e.nom as handler_last_name,
               admin_e.prenom as handler_first_name
        FROM demands d
        LEFT JOIN employees e ON d.requester_id = e.user_id
        LEFT JOIN employees admin_e ON d.handled_by = admin_e.user_id
      ''';
      
      final params = <String, dynamic>{};
      final conditions = <String>[];

      if (type != null) {
        conditions.add('d.type = :type');
        params['type'] = type;
      }
      
      if (status != null) {
        conditions.add('d.status = :status');
        params['status'] = status;
      }

      if (conditions.isNotEmpty) {
        query += ' WHERE ${conditions.join(' AND ')}';
      }

      query += ' ORDER BY d.created_at DESC';

      final result = await conn.execute(query, params);

      final demands = [];
      for (final row in result.rows) {
        demands.add({
          'id': row.colByName('id'),
          'type': row.colByName('type'),
          'description': row.colByName('description'),
          'requesterId': row.colByName('requester_id'),
          'requesterName': '${row.colByName('requester_first_name') ?? ''} ${row.colByName('requester_name') ?? ''}'.trim(),
          'status': row.colByName('status'),
          'createdAt': row.colByName('created_at').toString(),
          'handledBy': row.colByName('handled_by'),
          'handlerName': '${row.colByName('handler_first_name') ?? ''} ${row.colByName('handler_last_name') ?? ''}'.trim(),
          'resolutionNotes': row.colByName('resolution_notes'),
        });
      }

      // Don't close the connection - let the connection manager handle it
      return {'success': true, 'data': demands};
    } catch (e) {
      print('Error fetching demands: $e');
      return {'success': false, 'message': 'Failed to fetch demands'};
    }
  }

  // Get demand by ID
  static Future<Map<String, dynamic>> getDemandById(String id) async {
    try {
      final conn = DBConnection.getConnection();

      final result = await conn.execute(
        '''
        SELECT d.*, 
               e.nom as requester_name,
               e.prenom as requester_first_name,
               admin_e.nom as handler_last_name,
               admin_e.prenom as handler_first_name
        FROM demands d
        LEFT JOIN employees e ON d.requester_id = e.user_id
        LEFT JOIN employees admin_e ON d.handled_by = admin_e.user_id
        WHERE d.id = :id
        ''',
        {'id': id},
      );

      if (result.rows.isEmpty) {
        return {'success': false, 'message': 'Demand not found'};
      }

      final row = result.rows.first;
      final demand = {
        'id': row.colByName('id'),
        'type': row.colByName('type'),
        'description': row.colByName('description'),
        'requesterId': row.colByName('requester_id'),
        'requesterName': '${row.colByName('requester_first_name') ?? ''} ${row.colByName('requester_name') ?? ''}'.trim(),
        'status': row.colByName('status'),
        'createdAt': row.colByName('created_at').toString(),
        'handledBy': row.colByName('handled_by'),
        'handlerName': '${row.colByName('handler_first_name') ?? ''} ${row.colByName('handler_last_name') ?? ''}'.trim(),
        'resolutionNotes': row.colByName('resolution_notes'),
      };

      // Don't close the connection - let the connection manager handle it
      return {'success': true, 'data': demand};
    } catch (e) {
      print('Error fetching demand: $e');
      return {'success': false, 'message': 'Failed to fetch demand'};
    }
  }

  // Update demand status and resolution notes
  static Future<Map<String, dynamic>> updateDemand(String id, Map<String, dynamic> data) async {
    try {
      final conn = DBConnection.getConnection();

      // Build dynamic update query
      final updates = <String>[];
      final params = <String, dynamic>{'id': id};

      if (data.containsKey('status')) {
        // Validate and clean the status value
        String statusValue = data['status'].toString().toLowerCase().trim();
        
        // Ensure status is one of the allowed values
        final allowedStatuses = ['pending', 'approved', 'rejected', 'resolved'];
        if (!allowedStatuses.contains(statusValue)) {
          return {'success': false, 'message': 'Invalid status value. Must be one of: pending, approved, rejected, resolved'};
        }
        
        updates.add('status = :status');
        params['status'] = statusValue;
        
        // If status is being changed to approved, resolved or rejected, set handled_by
        if ((statusValue == 'approved' || statusValue == 'resolved' || statusValue == 'rejected') && data.containsKey('handledBy')) {
          updates.add('handled_by = :handledBy');
          params['handledBy'] = data['handledBy'];
        }
      }

      if (data.containsKey('resolutionNotes')) {
        updates.add('resolution_notes = :resolutionNotes');
        params['resolutionNotes'] = data['resolutionNotes'];
      }

      if (updates.isEmpty) {
        return {'success': false, 'message': 'No fields to update'};
      }

      // Get the demand before update to log the change
      final demandBefore = await getDemandById(id);
      
      await conn.execute(
        'UPDATE demands SET ${updates.join(', ')} WHERE id = :id',
        params,
      );
      
      // Log audit event
      final requesterId = demandBefore['data']['requesterId'];
      final status = data['status'];
      // Assuming the user making the change is the one in handledBy or using requesterId as fallback
      final changingUserId = params['handledBy'] ?? requesterId;
      await logAuditEvent(changingUserId, 'UPDATE_DEMAND_STATUS', 'Updated demand $id status to $status for user $requesterId');

      // Don't close the connection - let the connection manager handle it
      return {'success': true, 'message': 'Demand updated successfully'};
    } catch (e) {
      print('Error updating demand: $e');
      return {'success': false, 'message': 'Failed to update demand'};
    }
  }

  // Create notification for admins about new demand
  static Future<void> _createDemandNotification(String demandId, String type, String requesterId) async {
    try {
      final conn = DBConnection.getConnection();

      // Get requester name
      final requesterResult = await conn.execute(
        'SELECT nom, prenom FROM employees WHERE user_id = :userId',
        {'userId': requesterId},
      );

      String requesterName = 'Unknown';
      if (requesterResult.rows.isNotEmpty) {
        final row = requesterResult.rows.first;
        requesterName = '${row.colByName('prenom')} ${row.colByName('nom')}';
      }

      // Get all admin users
      final adminResult = await conn.execute(
        'SELECT DISTINCT u.id FROM users u WHERE u.role = \'Admin\''
      );

      for (final row in adminResult.rows) {
        final adminId = row.colByName('id');
        final title = 'New ${_formatDemandType(type)} Request';
        final message = 'New ${_formatDemandType(type)} request from $requesterName';
        
        await conn.execute(
          '''
          INSERT INTO notifications (user_id, title, message, type, timestamp, is_read) 
          VALUES (:userId, :title, :message, :type, :timestamp, :isRead)
          ''',
          {
            'userId': adminId,
            'title': title,
            'message': message,
            'type': 'demand',
            'timestamp': DateTime.now().toIso8601String(),
            'isRead': false,
          },
        );
      }

      // Don't close the connection - let the connection manager handle it
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Format demand type for display
  static String _formatDemandType(String type) {
    switch (type) {
      case 'password_reset':
        return 'Password Reset';
      case 'hardware':
        return 'Hardware';
      case 'administrative':
        return 'Administrative';
      case 'custom':
        return 'Custom';
      default:
        return type;
    }
  }

  // Get notifications for a specific user
  static Future<Map<String, dynamic>> getUserNotifications(String userId) async {
    try {
      final conn = DBConnection.getConnection();

      final result = await conn.execute(
        '''
        SELECT * FROM notifications 
        WHERE user_id = :userId 
        ORDER BY timestamp DESC
        ''',
        {'userId': userId},
      );

      final notifications = [];
      for (final row in result.rows) {
        notifications.add({
          'id': row.colByName('id'),
          'userId': row.colByName('user_id'),
          'title': row.colByName('title'),
          'message': row.colByName('message'),
          'type': row.colByName('type'),
          'timestamp': row.colByName('timestamp').toString(),
          'isRead': row.colByName('is_read') == 1,
        });
      }

      // Don't close the connection - let the connection manager handle it
      return {'success': true, 'data': notifications};
    } catch (e) {
      print('Error fetching notifications: $e');
      return {'success': false, 'message': 'Failed to fetch notifications'};
    }
  }

  // Mark notification as read
  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId, String userId) async {
    try {
      final conn = DBConnection.getConnection();

      await conn.execute(
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

      // Don't close the connection - let the connection manager handle it
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
        WHERE user_id = :userId
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

  // Handle password reset demand
  static Future<Map<String, dynamic>> handlePasswordResetDemand(String demandId, String adminId) async {
    try {
      final conn = DBConnection.getConnection();

      // Get the demand details
      final demandResult = await conn.execute(
        'SELECT requester_id FROM demands WHERE id = :demandId',
        {'demandId': demandId},
      );

      if (demandResult.rows.isEmpty) {
        return {'success': false, 'message': 'Demand not found'};
      }

      final requesterId = demandResult.rows.first.colByName('requester_id');

      // Generate a temporary password
      final tempPassword = RandomPasswordGenerator.generateTemporaryPassword();

      // Update the user's password
      await conn.execute(
        'UPDATE users SET password = :password WHERE id = :userId',
        {
          'password': tempPassword, // In a real app, this should be hashed
          'userId': requesterId,
        },
      );

      // Update demand status to resolved
      await conn.execute(
        '''
        UPDATE demands 
        SET status = 'resolved', handled_by = :handledBy, resolution_notes = 'Password reset to temporary password' 
        WHERE id = :demandId
        ''',
        {
          'handledBy': adminId,
          'demandId': demandId,
        },
      );

      // Create notification for the user about the password reset
      await conn.execute(
        '''
        INSERT INTO notifications (user_id, title, message, type, timestamp, is_read) 
        VALUES (:userId, :title, :message, :type, :timestamp, :isRead)
        ''',
        {
          'userId': requesterId,
          'title': 'Password Reset Completed',
          'message': 'Your password has been reset. Your new temporary password is: $tempPassword',
          'type': 'password_reset',
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': false,
        },
      );
      
      // Log audit event
      await logAuditEvent(adminId, 'PASSWORD_RESET_DEMAND_HANDLED', 'Handled password reset demand $demandId for user $requesterId');

      // Don't close the connection - let the connection manager handle it
      return {
        'success': true,
        'message': 'Password reset completed successfully',
        'temporaryPassword': tempPassword
      };
    } catch (e) {
      print('Error handling password reset demand: $e');
      return {'success': false, 'message': 'Failed to handle password reset demand'};
    }
  }

  // Removed duplicate method - using RandomPasswordGenerator.generateTemporaryPassword() instead

  // Audit logging method
  static Future<void> logAuditEvent(String userId, String action, String details, [String? targetUserId]) async {
    try {
      final conn = DBConnection.getConnection();
      
      await conn.execute(
        '''
        INSERT INTO audit_log (user_id, action, details, target_user_id, timestamp) 
        VALUES (:userId, :action, :details, :targetUserId, :timestamp)
        ''',
        {
          'userId': userId,
          'action': action,
          'details': details,
          'targetUserId': targetUserId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Don't close the connection - let the connection manager handle it
    } catch (e) {
      print('Error logging audit event: $e');
    }
  }
  
  // Update demand status with authorization check
  static Future<Map<String, dynamic>> updateDemandStatus(String id, Map<String, dynamic> data, String? currentUserId) async {
    try {
      // First, verify the current user has permission to update demand status
      if (currentUserId != null) {
        final conn = DBConnection.getConnection();
        
        // Check if the user is an admin
        final userResult = await conn.execute(
          'SELECT role FROM users WHERE id = :userId',
          {'userId': currentUserId},
        );
        
        if (userResult.rows.isNotEmpty) {
          final userRole = userResult.rows.first.colByName('role');
          if (userRole != 'Admin') {
            return {'success': false, 'message': 'Only administrators can update demand status'};
          }
        } else {
          return {'success': false, 'message': 'User not found'};
        }
      }
      
      // Call the main updateDemand method to perform the actual update
      return await updateDemand(id, data);
    } catch (e) {
      print('Error updating demand status: $e');
      return {'success': false, 'message': 'Failed to update demand status'};
    }
  }
}
// Custom Random implementation for temporary password generation
class RandomPasswordGenerator {
  static final math.Random _random = math.Random.secure();
  
  static String generateTemporaryPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$^&*()%';
    var password = '';
    for (int i = 0; i < 12; i++) {
      password += chars[_random.nextInt(chars.length)];
    }
    return password;
  }
}