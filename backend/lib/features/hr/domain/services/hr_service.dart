import '../../data/repositories/hr_repository.dart';
import '../../../notification/domain/services/notification_service.dart';
import '../../../../shared/services/audit_service.dart';

class HrService {
  static final HrRepository _repository = HrRepository();

  // --- Attendance ---

  static Future<Map<String, dynamic>> getAttendance(String employeeId, {String? startDate, String? endDate}) async {
    try {
      final records = await _repository.getAttendance(employeeId, startDate: startDate, endDate: endDate);
      return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
    } catch (e) {
      print('getAttendance error: $e');
      return {'success': false, 'message': 'Failed to retrieve attendance'};
    }
  }

  static Future<Map<String, dynamic>> logAttendance(Map<String, dynamic> data, {String? callerId}) async {
    try {
      if (data['employee_id'] == null || data['attendance_date'] == null) {
        return {'success': false, 'message': 'Missing employee_id or attendance_date'};
      }
      await _repository.logAttendance(data);
      
      await AuditService.log(callerId ?? 'SYSTEM', 'ATTENDANCE_LOGGED', {
        'employee_id': data['employee_id'],
        'date': data['attendance_date'],
        'status': data['statut'] ?? 'P',
      });
      
      return {'success': true, 'message': 'Attendance logged successfully'};
    } catch (e) {
      print('logAttendance error: $e');
      return {'success': false, 'message': 'Failed to log attendance'};
    }
  }

  // --- Leave Requests ---

  static Future<Map<String, dynamic>> getLeaveRequests(String? callerRole, String callerId) async {
    try {
      if (callerRole == 'Admin' || callerRole == 'RH') {
        final records = await _repository.getAllLeaveRequests();
        return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
      }
      final records = await _repository.getLeaveRequests(callerId);
      return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
    } catch (e) {
      print('getLeaveRequests error: $e');
      return {'success': false, 'message': 'Failed to fetch leave requests'};
    }
  }

  static Future<Map<String, dynamic>> submitLeaveRequest(String employeeId, Map<String, dynamic> data) async {
    try {
      if (data['start_date'] == null || data['end_date'] == null || data['leave_type'] == null) {
        return {'success': false, 'message': 'Missing required fields for leave request'};
      }
      
      data['employee_id'] = employeeId;
      data['status'] = 'pending';
      
      await _repository.submitLeaveRequest(data);
      return {'success': true, 'message': 'Leave request submitted'};
    } catch (e) {
      print('submitLeaveRequest error: $e');
      return {'success': false, 'message': 'Failed to submit leave request'};
    }
  }

  static Future<Map<String, dynamic>> updateLeaveStatus(int id, String status, String approvedBy) async {
    try {
      final requester = await _repository.getLeaveRequestEmployeeId(id);
      if (requester == approvedBy) {
        return {'success': false, 'message': 'You cannot approve your own leave request.'};
      }
      
      await _repository.updateLeaveStatus(id, status, approvedBy);
      
      await AuditService.log(approvedBy, 'LEAVE_STATUS_UPDATED', {
        'requestId': id,
        'newStatus': status,
      });
      
      final targetEmployee = await _repository.getLeaveRequestEmployeeId(id);
      if (targetEmployee != null) {
        await NotificationService.createNotification(
          userId: targetEmployee,
          title: 'Leave Request \${status.toUpperCase()}',
          message: 'Your leave request status has been updated to \$status.',
          type: 'HR_LEAVE',
        );
      }
      
      return {'success': true, 'message': 'Leave status updated'};
    } catch (e) {
      print('updateLeaveStatus error: $e');
      return {'success': false, 'message': 'Failed to update leave status'};
    }
  }

  // --- Remote Work ---

  static Future<Map<String, dynamic>> getRemoteWorkRequests(String? callerRole, String callerId) async {
    try {
      if (callerRole == 'Admin' || callerRole == 'RH') {
        final records = await _repository.getAllRemoteWorkRequests();
         return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
      }
      final records = await _repository.getRemoteWorkRequests(callerId);
      return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
    } catch (e) {
      print('getRemoteWorkRequests error: $e');
      return {'success': false, 'message': 'Failed to fetch remote work requests'};
    }
  }

  static Future<Map<String, dynamic>> submitRemoteWorkRequest(String employeeId, Map<String, dynamic> data) async {
    try {
      if (data['remote_date'] == null) {
        return {'success': false, 'message': 'Missing remote_date'};
      }
      
      data['employee_id'] = employeeId;
      data['status'] = 'pending';
      
       await _repository.submitRemoteWorkRequest(data);
      return {'success': true, 'message': 'Remote work request submitted'};
    } catch (e) {
      print('submitRemoteWorkRequest error: $e');
      return {'success': false, 'message': 'Failed to submit remote work request'};
    }
  }

  static Future<Map<String, dynamic>> updateRemoteWorkStatus(int id, String status, String approvedBy) async {
    try {
      final requester = await _repository.getRemoteWorkEmployeeId(id);
      if (requester == approvedBy) {
        return {'success': false, 'message': 'You cannot approve your own remote work request.'};
      }
      
      await _repository.updateRemoteWorkStatus(id, status, approvedBy);
      
      await AuditService.log(approvedBy, 'REMOTE_WORK_STATUS_UPDATED', {
        'requestId': id,
        'newStatus': status,
      });
      
      final targetEmployee = await _repository.getRemoteWorkEmployeeId(id);
      if (targetEmployee != null) {
        await NotificationService.createNotification(
          userId: targetEmployee,
          title: 'Remote Work \${status.toUpperCase()}',
          message: 'Your remote work request has been updated to \$status.',
          type: 'HR_REMOTE',
        );
      }
      
      return {'success': true, 'message': 'Remote work status updated'};
    } catch (e) {
      print('updateRemoteWorkStatus error: $e');
      return {'success': false, 'message': 'Failed to update remote work status'};
    }
  }

  // --- Salaries & Bonuses ---

  static Future<Map<String, dynamic>> getSalaries(String? callerRole, String callerId, {String? targetEmployeeId}) async {
    try {
      if (callerRole == 'Admin' || callerRole == 'Comptable' || callerRole == 'RH') {
        final records = targetEmployeeId != null 
            ? await _repository.getSalaries(targetEmployeeId)
            : await _repository.getAllSalaries();
         return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
      }
      final records = await _repository.getSalaries(callerId);
      return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
    } catch (e) {
      print('getSalaries error: $e');
      return {'success': false, 'message': 'Failed to fetch salaries'};
    }
  }

  static Future<Map<String, dynamic>> createSalary(Map<String, dynamic> data, {String? callerId}) async {
    try {
      if (data['employee_id'] == null || data['base_salary'] == null || data['salary_month'] == null) {
         return {'success': false, 'message': 'Missing required fields for salary'};
      }

      await _repository.createSalary(data);
      await AuditService.log(callerId ?? 'SYSTEM', 'SALARY_CREATED', {
        'employee_id': data['employee_id'],
        'base_salary': data['base_salary'],
        'month': data['salary_month'],
      });
      return {'success': true, 'message': 'Salary created/updated successfully'};
    } catch (e) {
      print('createSalary error: $e');
      return {'success': false, 'message': 'Failed to create salary'};
    }
  }
  
  static Future<Map<String, dynamic>> updateSalaryStatus(int id, String status, {String? callerId}) async {
    try {
      final targetEmployee = await _repository.getSalaryEmployeeId(id);
      if (callerId != null && targetEmployee == callerId) {
        return {'success': false, 'message': 'You cannot update your own salary status for audit integrity.'};
      }
      
      await _repository.updateSalaryStatus(id, status);
      await AuditService.log(callerId ?? 'SYSTEM', 'SALARY_STATUS_UPDATED', {
        'salaryId': id,
        'newStatus': status,
      });
      return {'success': true, 'message': 'Salary status updated'};
    } catch (e) {
      print('updateSalaryStatus error: $e');
      return {'success': false, 'message': 'Failed to update salary status'};
    }
  }

  static Future<Map<String, dynamic>> grantBonus(Map<String, dynamic> data) async {
     try {
       if (data['employee_id'] == null || data['amount'] == null) {
          return {'success': false, 'message': 'Missing employee_id or amount'};
       }
       
       if (data['granted_by'] != null && data['employee_id'].toString() == data['granted_by'].toString()) {
          return {'success': false, 'message': 'You cannot grant a bonus to yourself.'};
       }
       
       await _repository.grantBonus(data);
       
       await NotificationService.createNotification(
         userId: data['employee_id'],
         title: 'Bonus Granted!',
         message: "You have been granted a new bonus of ${data['amount']}.",
         type: 'HR_BONUS',
       );

       await AuditService.log(data['granted_by']?.toString() ?? 'SYSTEM', 'BONUS_GRANTED_MANUAL', {
         'employee_id': data['employee_id'],
         'amount': data['amount'],
         'reason': data['reason'],
       });
       
       return {'success': true, 'message': 'Bonus granted successfully'};
     } catch(e) {
       print('grantBonus error: $e');
       return {'success': false, 'message': 'Failed to grant bonus'};
     }
  }
  
  static Future<Map<String, dynamic>> bulkGenerateSalaries(String month, {String? callerId}) async {
    try {
      final count = await _repository.bulkGenerateSalaries(month);
      await AuditService.log(callerId ?? 'SYSTEM', 'BULK_SALARY_GENERATION', {
        'month': month,
        'recordCount': count,
      });
      return {'success': true, 'message': 'Successfully generated \$count salaries for \$month'};
    } catch(e) {
      print('bulkGenerateSalaries error: $e');
      return {'success': false, 'message': 'Failed to bulk generate salaries'};
    }
  }
  
  static Future<Map<String, dynamic>> getBonuses(String employeeId) async {
    try {
       final records = await _repository.getBonuses(employeeId);
       return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
    } catch(e) {
       print('getBonuses error: $e');
       return {'success': false, 'message': 'Failed to fetch bonuses'};
    }
  }

  static Future<Map<String, dynamic>> bulkCorrectAttendance(List<String> employeeIds, String date, String status, {String? callerId}) async {
    try {
      int count = 0;
      for (final id in employeeIds) {
        await _repository.logAttendance({
          'employee_id': id,
          'attendance_date': date,
          'status': status,
        });
        count++;
      }
      
      await AuditService.log(callerId ?? 'SYSTEM', 'BULK_ATTENDANCE_CORRECTION', {
        'date': date,
        'status': status,
        'employeeCount': employeeIds.length,
      });
      return {'success': true, 'message': 'Successfully updated \$count attendance records'};
    } catch (e) {
      return {'success': false, 'message': 'Bulk correction failed: \$e'};
    }
  }
}
