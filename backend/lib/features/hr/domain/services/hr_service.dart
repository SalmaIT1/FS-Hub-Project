import '../../data/repositories/hr_repository.dart';
import '../../../notification/domain/services/notification_service.dart';
import '../../../../shared/services/audit_service.dart';
import '../../../../shared/database/connection.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

class HrService {
  static final HrRepository _repository = HrRepository();
  static final _db = DBConnection.getConnection();

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
      
      // P0-02 FIX: Prevent Future Attendance Fraud
      if (!_validateDateNotFuture(data['attendance_date']?.toString())) {
        return {'success': false, 'message': 'Cannot log attendance for future dates.'};
      }

      await _repository.logAttendance(data);
      
      await AuditService.log(callerId ?? 'SYSTEM', 'ATTENDANCE_LOGGED', {
        'employee_id': data['employee_id'],
        'date': data['attendance_date'],
        'status': data['status'] ?? data['statut'] ?? 'present',
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
      
      if (data['leave_type'] == 'paid_leave') {
        final startDate = DateTime.parse(data['start_date'].toString());
        final usedDays = await _repository.getUsedPaidLeaveDaysInYear(employeeId, startDate.year);
        
        int requestingDays = 0;
        if (data['total_days'] != null) {
          requestingDays = int.tryParse(data['total_days'].toString()) ?? 0;
        } else {
          final endDate = DateTime.parse(data['end_date'].toString());
          requestingDays = endDate.difference(startDate).inDays + 1;
        }
        
        final remainingBalance = 21 - usedDays;
        
        if (remainingBalance <= 0) {
           return {'success': false, 'message': 'Paid leave quota exceeded. You have 0 days remaining for this year.'};
        } else if (requestingDays > remainingBalance) {
           return {'success': false, 'message': 'Paid leave quota exceeded. You only have $remainingBalance day(s) left.'};
        }
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
          title: 'Leave Request ${status.toUpperCase()}',
          message: 'Your leave request status has been updated to $status.',
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
        'message': 'Demande de télétravail soumise. (Reste : ${2 - count} jour(s) pour cette semaine)'
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
          title: 'Remote Work ${status.toUpperCase()}',
          message: 'Your remote work request has been updated to $status.',
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

       final amount = double.tryParse(data['amount'].toString()) ?? 0.0;
       if (amount <= 0) {
         return {'success': false, 'message': 'Bonus amount must be strictly positive.'};
       }

       final caller = data['granted_by']?.toString() ?? 'SYSTEM';
       final reason = data['reason']?.toString() ?? 'Sans motif';
       final employeeId = data['employee_id'].toString();

       // ATOMIC FIX: Both the HR bonus row and the Finance expense row are written
       // inside the same DB transaction. If either INSERT fails, both are rolled back,
       // eliminating the ledger desynchronisation / embezzlement risk.
       await _db.transaction((tx) async {
         // 1. Insert bonus record
         await tx.execute(
           '''INSERT INTO bonuses (employee_id, amount, reason, bonus_type, granted_by, granted_date)
              VALUES (:employee_id, :amount, :reason, :bonus_type, :granted_by, :granted_date)''',
           {
             'employee_id': employeeId,
             'amount': amount,
             'reason': reason,
             'bonus_type': data['bonus_type'] ?? 'performance',
             'granted_by': caller,
             'granted_date': data['granted_date'] ?? DateTime.now().toIso8601String().split('T')[0],
           },
         );

         // 2. Insert matching Finance expense row (same tx — will roll back if this throws)
         await tx.execute(
           '''INSERT INTO depenses_entreprise (montant, date_depense, description, category_id, created_by, status)
              VALUES (:montant, :date, :description, :category_id, :created_by, 'approved_finance')''',
           {
             'montant': amount,
             'date': DateTime.now().toIso8601String().split('T')[0],
             'description': 'Bonus accordé à l\'employé #$employeeId: $reason',
             'category_id': 1,
             'created_by': caller,
           },
         );
       });

       // Post-commit side-effects (non-critical; failures do not affect data integrity)
       await NotificationService.createNotification(
         userId: employeeId,
         title: 'Bonus Granted!',
         message: 'You have been granted a new bonus of $amount DT.',
         type: 'HR_BONUS',
       );

       await AuditService.log(caller, 'BONUS_GRANTED_MANUAL', {
         'employee_id': employeeId,
         'amount': amount,
         'reason': reason,
       });
       
       return {'success': true, 'message': 'Bonus granted successfully and recorded as expense'};
     } catch(e) {
       print('grantBonus error: $e');
       return {'success': false, 'message': 'Failed to grant bonus: transaction rolled back'};
     }
  }

  static Future<Map<String, dynamic>> bulkGrantBonuses(List<String> employeeIds, Map<String, dynamic> data) async {
    try {
      if (employeeIds.isEmpty || data['amount'] == null) {
        return {'success': false, 'message': 'Missing employees or amount'};
      }

      final caller = data['granted_by']?.toString() ?? 'SYSTEM';
      final amountPerEmp = double.tryParse(data['amount'].toString()) ?? 0.0;

      if (amountPerEmp <= 0) {
         return {'success': false, 'message': 'Bonus amount must be strictly positive.'};
      }

      final reason = data['reason'] ?? 'Sans motif';
      final bonusType = data['bonus_type'] ?? 'performance';
      final grantedDate = data['granted_date'] ?? DateTime.now().toIso8601String().split('T')[0];

      // ATOMIC FIX: All bonus rows AND the consolidated Finance expense row are written
      // inside a single DB transaction. Full rollback if any part fails.
      int count = 0;
      await _db.transaction((tx) async {
        // 1. Bulk-insert individual bonus rows
        for (final empId in employeeIds) {
          await tx.execute(
            '''INSERT INTO bonuses (employee_id, amount, reason, bonus_type, granted_by, granted_date)
               VALUES (:empId, :amount, :reason, :bonusType, :by, :date)''',
            {
              'empId': empId,
              'amount': amountPerEmp,
              'reason': reason,
              'bonusType': bonusType,
              'by': caller,
              'date': grantedDate,
            },
          );
          count++;
        }

        final totalAmount = amountPerEmp * count;

        // 2. Insert consolidated Finance expense row (same tx)
        await tx.execute(
          '''INSERT INTO depenses_entreprise (montant, date_depense, description, category_id, created_by, status)
             VALUES (:montant, :date, :description, :category_id, :created_by, 'approved_finance')''',
          {
            'montant': totalAmount,
            'date': DateTime.now().toIso8601String().split('T')[0],
            'description': 'Attribution groupée de primes ($count employés) @ $amountPerEmp DT/pers. Motif: $reason',
            'category_id': 1,
            'created_by': caller,
          },
        );
      });

      final totalAmount = amountPerEmp * count;

      // Post-commit side-effects
      for (final id in employeeIds) {
          await NotificationService.createNotification(
            userId: id,
            title: 'Bonus Granted!',
            message: 'You have been granted a new bonus of $amountPerEmp DT.',
            type: 'HR_BONUS',
          );
      }

      await AuditService.log(caller, 'BONUS_GRANTED_BULK', {
        'count': count,
        'amount_per_employee': amountPerEmp,
        'total_impact': totalAmount,
        'type': bonusType,
      });

      return {'success': true, 'message': 'Successfully granted $count bonuses and recorded $totalAmount DT total expense.'};
    } catch (e) {
       print('bulkGrantBonuses error: $e');
       return {'success': false, 'message': 'Batch operation failed: transaction rolled back'};
    }
  }
  
  static Future<Map<String, dynamic>> bulkGenerateSalaries(String month, {bool fullResync = false, String? callerId}) async {
    try {
      final count = await _repository.bulkGenerateSalaries(month, fullResync: fullResync);
      await AuditService.log(callerId ?? 'SYSTEM', 'BULK_SALARY_GENERATION', {
        'month': month,
        'recordCount': count,
        'fullResync': fullResync,
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
      if (!_validateDateNotFuture(date)) {
        return {'success': false, 'message': 'Cannot correct attendance for future dates.'};
      }

      int count = 0;
      await _db.transaction((tx) async {
        for (final id in employeeIds) {
          await tx.execute(
            '''INSERT INTO attendance (employee_id, attendance_date, status, created_at)
               VALUES (:id, :date, :status, NOW())
               ON DUPLICATE KEY UPDATE status = :status, updated_at = NOW()''',
            {
              'id': id,
              'date': date,
              'status': status,
            },
          );
          count++;
        }
      });
      
      await AuditService.log(callerId ?? 'SYSTEM', 'BULK_ATTENDANCE_CORRECTION', {
        'date': date,
        'status': status,
        'employeeCount': employeeIds.length,
      });
      return {'success': true, 'message': 'Successfully updated $count attendance records'};
    } catch (e) {
      print('bulkCorrectAttendance error: $e');
      return {'success': false, 'message': 'Bulk correction failed: transaction rolled back'};
    }
  }

  static Future<String?> generatePayslipHtmlForSalary(int salaryId) async {
    String? logoBase64;
    try {
      // PRO-FIX: Robust logo path resolution using absolute path from project root
      // Assumes we are running from project root (StudioProjects/fs_hub/backend)
      final logoPath = Platform.environment['ASSETS_PATH'] != null 
          ? p.join(Platform.environment['ASSETS_PATH']!, 'images', 'logo.png')
          : p.join(Directory.current.path, '..', 'assets', 'images', 'logo.png');
          
      final logoFile = File(logoPath);
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

  // --- Helpers ---

  static bool _validateDateNotFuture(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final targetDate = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return !targetDate.isAfter(today);
    } catch (_) {
      return false;
    }
  }
}
