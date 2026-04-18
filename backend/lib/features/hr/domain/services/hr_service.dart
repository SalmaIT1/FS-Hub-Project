import '../../data/repositories/hr_repository.dart';
import '../../../notification/domain/services/notification_service.dart';
import '../../../../shared/services/audit_service.dart';
import '../../../finance/domain/services/expense_service.dart';
import '../../../finance/data/models/expense_model.dart';
import 'dart:io';
import 'dart:convert';

class HrService {
  static final HrRepository _repository = HrRepository();
  static final ExpenseService _expenseService = ExpenseService();

  // --- Attendance ---

  static Future<Map<String, dynamic>> getAllAttendance(String date) async {
    try {
      final records = await _repository.getAllAttendance(date);
      return {'success': true, 'data': records.map((r) => r.toMap()).toList()};
    } catch (e) {
      print('getAllAttendance error: $e');
      return {'success': false, 'message': 'Failed to retrieve attendance log'};
    }
  }

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
      
      // Normalize date to YYYY-MM-DD
      if (data['attendance_date'].toString().contains('T')) {
        data['attendance_date'] = data['attendance_date'].toString().split('T')[0];
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
        return {'success': true, 'data': records};
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
        return {'success': true, 'data': records};
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
      
      final remoteDate = DateTime.parse(data['remote_date'].toString());
      
      // Validation : Quota de 3 jours par semaine
      final count = await _repository.countRemoteWorkDaysInWeek(employeeId, remoteDate);
      if (count >= 3) {
        return {
          'success': false, 
          'message': 'Vous avez déjà atteint la limite de 3 jours de télétravail pour cette semaine.'
        };
      }
      
      data['employee_id'] = employeeId;
      data['status'] = 'pending';
      
       await _repository.submitRemoteWorkRequest(data);
      return {
        'success': true, 
        'message': 'Demande de télétravail soumise. (Reste : \${2 - count} jour(s) pour cette semaine)'
      };
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
       
       // Record as company expense (Charge)
       final amount = double.tryParse(data['amount'].toString()) ?? 0.0;
       await _expenseService.createCompanyExpense(ExpenseModel(
         categorie: 'Salaires et Charges Sociales',
         montant: amount,
         dateDepense: DateTime.now(),
         description: 'Bonus accordé à l\'employé #${data['employee_id']}: ${data['reason'] ?? 'Sans motif'}',
         categoryId: 1, // Category ID for Salaries & Social Charges
         createdBy: data['granted_by']?.toString() ?? 'SYSTEM',
         status: 'approved_finance', // Auto-approved as it's a confirmed HR action
       ));

       await NotificationService.createNotification(
         userId: data['employee_id'].toString(),
         title: 'Bonus Granted!',
         message: "You have been granted a new bonus of $amount DT.",
         type: 'HR_BONUS',
       );

       await AuditService.log(data['granted_by']?.toString() ?? 'SYSTEM', 'BONUS_GRANTED_MANUAL', {
         'employee_id': data['employee_id'],
         'amount': amount,
         'reason': data['reason'],
       });
       
       return {'success': true, 'message': 'Bonus granted successfully and recorded as expense'};
     } catch(e) {
       print('grantBonus error: $e');
       return {'success': false, 'message': 'Failed to grant bonus'};
     }
  }

  static Future<Map<String, dynamic>> bulkGrantBonuses(List<String> employeeIds, Map<String, dynamic> data) async {
    try {
      if (employeeIds.isEmpty || data['amount'] == null) {
        return {'success': false, 'message': 'Missing employees or amount'};
      }

      final count = await _repository.bulkGrantBonuses(employeeIds, data);
      final caller = data['granted_by']?.toString() ?? 'SYSTEM';
      final amountPerEmp = double.tryParse(data['amount'].toString()) ?? 0.0;
      final totalAmount = amountPerEmp * count;

      // Record bulk operation as one consolidated company expense
      await _expenseService.createCompanyExpense(ExpenseModel(
         categorie: 'Salaires et Charges Sociales',
         montant: totalAmount,
         dateDepense: DateTime.now(),
         description: 'Attribution groupée de primes ($count employés) @ $amountPerEmp DT/pers. Motif: ${data['reason'] ?? 'Sans motif'}',
         categoryId: 1, 
         createdBy: caller,
         status: 'approved_finance',
      ));

      // Mass notify
      for (final id in employeeIds) {
          await NotificationService.createNotification(
            userId: id,
            title: 'Bonus Granted!',
            message: "You have been granted a new bonus of $amountPerEmp DT.",
            type: 'HR_BONUS',
          );
      }

      await AuditService.log(caller, 'BONUS_GRANTED_BULK', {
        'count': count,
        'amount_per_employee': amountPerEmp,
        'total_impact': totalAmount,
        'type': data['bonus_type'] ?? 'performance',
      });

      return {'success': true, 'message': 'Successfully granted $count bonuses and recorded $totalAmount DT total expense.'};
    } catch (e) {
       print('bulkGrantBonuses error: $e');
       return {'success': false, 'message': 'Batch operation failed'};
    }
  }
  
  static Future<Map<String, dynamic>> bulkGenerateSalaries(String month, {String? callerId}) async {
    try {
      final count = await _repository.bulkGenerateSalaries(month);
      await AuditService.log(callerId ?? 'SYSTEM', 'BULK_SALARY_GENERATION', {
        'month': month,
        'recordCount': count,
      });
      return {'success': true, 'message': 'Successfully generated $count salaries for $month'};
    } catch(e) {
      print('bulkGenerateSalaries error: $e');
      return {'success': false, 'message': 'Failed to bulk generate salaries'};
    }
  }
  
  static Future<Map<String, dynamic>> getBonuses(String? callerRole, String callerId, {String? targetEmployeeId}) async {
    try {
       if (callerRole == 'Admin' || callerRole == 'RH' || callerRole == 'Comptable') {
         final records = targetEmployeeId != null 
             ? await _repository.getBonuses(targetEmployeeId)
             : await _repository.getAllBonuses();
         return {'success': true, 'data': records};
       }
       final records = await _repository.getBonuses(callerId);
       return {'success': true, 'data': records};
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
      return {'success': true, 'message': 'Successfully updated $count attendance records'};
    } catch (e) {
      print('bulkCorrectAttendance error: $e');
      return {'success': false, 'message': 'Bulk correction failed'};
    }
  }

  static Future<String?> generatePayslipHtmlForSalary(int salaryId) async {
    String? logoBase64;
    try {
      // Find logo in assets (relative to backend root: ../assets/images/logo.png)
      final logoFile = File('../assets/images/logo.png');
      if (await logoFile.exists()) {
        final bytes = await logoFile.readAsBytes();
        logoBase64 = base64Encode(bytes);
      }
    } catch (e) {
      print('Warning: Could not load logo for payslip: $e');
    }
    return await _repository.generatePayslipHtmlForSalary(salaryId, logoBase64: logoBase64);
  }

  static Future<String?> getSalaryEmployeeId(int salaryId) async {
    return await _repository.getSalaryEmployeeId(salaryId);
  }
}
