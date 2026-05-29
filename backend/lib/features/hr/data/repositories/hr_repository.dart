import '../../../../shared/database/connection.dart';
import '../../domain/repositories/hr_repository_port.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/remote_work_model.dart';
import '../models/salary_model.dart';
import '../models/bonus_model.dart';

class HrRepository implements HrRepositoryPort {
  final _db = DBConnection.getConnection();
  
  Future<String> _getSetting(String key, String defaultValue) async {
    try {
      final res = await _db.execute(
        'SELECT setting_value FROM system_settings WHERE setting_key = :k',
        {'k': key},
      );
      if (res.rows.isEmpty) return defaultValue;
      return res.rows.first.colByName('setting_value')?.toString() ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  // --- Attendance ---

  Future<List<AttendanceModel>> getAttendance(String employeeId, {String? startDate, String? endDate}) async {
    String query = 'SELECT * FROM attendance WHERE employee_id = :employeeId';
    Map<String, dynamic> params = {'employeeId': employeeId};

    if (startDate != null && endDate != null) {
      query += ' AND attendance_date BETWEEN :startDate AND :endDate';
      params['startDate'] = startDate;
      params['endDate'] = endDate;
    }
    query += ' ORDER BY attendance_date DESC';

    final result = await _db.execute(query, params);
    return result.rows.map((row) => AttendanceModel.fromMap(row.assoc())).toList();
  }

  Future<List<AttendanceModel>> getAllAttendance(String date) async {
    final result = await _db.execute(
      'SELECT * FROM attendance WHERE attendance_date = :date',
      {'date': date},
    );
    return result.rows.map((row) => AttendanceModel.fromMap(row.assoc())).toList();
  }

  Future<void> logAttendance(Map<String, dynamic> data) async {
    await _db.execute(
      '''INSERT INTO attendance (employee_id, attendance_date, check_in, check_out, status, work_hours, overtime_hours, notes) 
         VALUES (:employee_id, :attendance_date, :check_in, :check_out, :status, :work_hours, :overtime_hours, :notes)
         ON DUPLICATE KEY UPDATE 
         check_in = VALUES(check_in), check_out = VALUES(check_out), status = VALUES(status), 
         work_hours = VALUES(work_hours), overtime_hours = VALUES(overtime_hours), notes = VALUES(notes)''',
      data,
    );
  }

  // --- Leaves ---

  Future<List<LeaveRequestModel>> getLeaveRequests(String employeeId) async {
    final result = await _db.execute(
      'SELECT * FROM leave_requests WHERE employee_id = :employeeId ORDER BY created_at DESC',
      {'employeeId': employeeId},
    );
    return result.rows.map((row) => LeaveRequestModel.fromMap(row.assoc())).toList();
  }
  
  Future<List<Map<String, dynamic>>> getAllLeaveRequests() async {
    final result = await _db.execute(
      '''SELECT lr.*, e.nom, e.prenom FROM leave_requests lr 
         JOIN employees e ON lr.employee_id = e.id 
         ORDER BY lr.created_at DESC''',
      {},
    );
    return result.rows.map((row) {
      final map = row.assoc();
      return LeaveRequestModel.fromMap(map).toMap()..['nom'] = map['nom']..['prenom'] = map['prenom'];
    }).toList();
  }

  Future<int> getUsedPaidLeaveDaysInYear(String employeeId, int year) async {
    final result = await _db.execute(
      '''SELECT SUM(total_days) as used FROM leave_requests 
         WHERE employee_id = :employeeId 
         AND status != 'rejected' AND status != 'cancelled' 
         AND YEAR(start_date) = :year 
         AND leave_type = 'paid_leave' ''',
      {'employeeId': employeeId, 'year': year},
    );
    return int.tryParse(result.rows.first.colByName('used')?.toString() ?? '0') ?? 0;
  }

  Future<void> submitLeaveRequest(Map<String, dynamic> data) async {
    await _db.transaction((tx) async {
      final employeeId = data['employee_id']?.toString() ?? '';
      
      // P1.2 FIX: Lock the employee row to serialize leave requests for this specific user.
      // This prevents multiple concurrent requests from bypassing the annual quota check.
      await tx.execute('SELECT id FROM employees WHERE id = :id FOR UPDATE', {'id': employeeId});

      if (data['leave_type']?.toString() == 'paid_leave') {
        final startDateStr = data['start_date']?.toString() ?? '';
        final year = startDateStr.isNotEmpty
            ? (DateTime.tryParse(startDateStr)?.year ?? DateTime.now().year)
            : DateTime.now().year;
        final requestedDays =
            int.tryParse(data['total_days']?.toString() ?? '0') ?? 0;

        // Perform quota check within the transaction with the lock held
        final result = await tx.execute(
          '''SELECT SUM(total_days) as used FROM leave_requests 
             WHERE employee_id = :employeeId 
             AND status != 'rejected' AND status != 'cancelled' 
             AND YEAR(start_date) = :year 
             AND leave_type = 'paid_leave' ''',
          {'employeeId': employeeId, 'year': year},
        );
        final usedDays = int.tryParse(result.rows.first.colByName('used')?.toString() ?? '0') ?? 0;
        final remaining = 21 - usedDays;

        if (usedDays + requestedDays > 21) {
          throw Exception(
            'Annual paid leave quota exceeded. '
            'You have used $usedDays day(s) this year and have $remaining '
            'day(s) remaining. Requested: $requestedDays day(s).'
          );
        }
      }

      await tx.execute(
        '''INSERT INTO leave_requests (employee_id, leave_type, start_date, end_date, total_days, reason, status)
           VALUES (:employee_id, :leave_type, :start_date, :end_date, :total_days, :reason, :status)''',
        data,
      );
    });
  }

  Future<String?> getLeaveRequestEmployeeId(int id) async {
    final result = await _db.execute('SELECT employee_id FROM leave_requests WHERE id = :id', {'id': id});
    if (result.rows.isNotEmpty) return result.rows.first.colAt(0).toString();
    return null;
  }

  Future<void> updateLeaveStatus(int id, String status, String approvedBy) async {
    await _db.execute(
      'UPDATE leave_requests SET status = :status, approved_by = :approvedBy, approved_at = NOW() WHERE id = :id',
      {'id': id, 'status': status, 'approvedBy': approvedBy},
    );
  }

  // --- Remote Work ---

  Future<List<RemoteWorkModel>> getRemoteWorkRequests(String employeeId) async {
    final result = await _db.execute(
      'SELECT * FROM remote_work WHERE employee_id = :employeeId ORDER BY created_at DESC',
      {'employeeId': employeeId},
    );
    return result.rows.map((row) => RemoteWorkModel.fromMap(row.assoc())).toList();
  }
  
  Future<List<Map<String, dynamic>>> getAllRemoteWorkRequests() async {
    final result = await _db.execute(
      '''SELECT rw.*, e.nom, e.prenom FROM remote_work rw 
         JOIN employees e ON rw.employee_id = e.id 
         ORDER BY rw.created_at DESC''',
      {},
    );
    return result.rows.map((row) {
      final map = row.assoc();
      return RemoteWorkModel.fromMap(map).toMap()..['nom'] = map['nom']..['prenom'] = map['prenom'];
    }).toList();
  }

  Future<void> submitRemoteWorkRequest(Map<String, dynamic> data) async {
    await _db.execute(
      '''INSERT INTO remote_work (employee_id, remote_date, type, reason, status)
         VALUES (:employee_id, :remote_date, :type, :reason, :status)''',
      data,
    );
  }

  Future<int> countRemoteWorkDaysInWeek(String employeeId, DateTime date) async {
    // Calculate start (Monday) and end (Sunday) of the week for the given date
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(Duration(days: 6));
    
    final startDate = monday.toIso8601String().split('T')[0];
    final endDate = sunday.toIso8601String().split('T')[0];

    final result = await _db.execute(
      '''SELECT COUNT(*) as count FROM remote_work 
         WHERE employee_id = :employeeId 
         AND remote_date BETWEEN :startDate AND :endDate
         AND status != 'rejected' AND status != 'canceled' ''',
      {
        'employeeId': employeeId,
        'startDate': startDate,
        'endDate': endDate,
      },
    );
    
    return int.tryParse(result.rows.first.colByName('count')?.toString() ?? '0') ?? 0;
  }

  Future<String?> getRemoteWorkEmployeeId(int id) async {
    final result = await _db.execute('SELECT employee_id FROM remote_work WHERE id = :id', {'id': id});
    if (result.rows.isNotEmpty) return result.rows.first.colAt(0).toString();
    return null;
  }

  Future<void> updateRemoteWorkStatus(int id, String status, String approvedBy) async {
    await _db.execute(
      'UPDATE remote_work SET status = :status, approved_by = :approvedBy WHERE id = :id',
      {'id': id, 'status': status, 'approvedBy': approvedBy},
    );
  }

  // --- Salaries & Bonuses ---

  Future<List<SalaryModel>> getSalaries(String employeeId) async {
    final result = await _db.execute(
      '''SELECT s.*, e.nom, e.prenom FROM salaries s 
         JOIN employees e ON s.employee_id = e.id 
         WHERE s.employee_id = :employeeId ORDER BY s.salary_month DESC''',
      {'employeeId': employeeId},
    );
    return result.rows.map((row) => SalaryModel.fromMap(row.assoc())).toList();
  }
  
  Future<List<SalaryModel>> getAllSalaries({String? before, int limit = 50}) async {
    limit = limit > 200 ? 200 : limit;
    String query = '''
      SELECT s.*, e.nom, e.prenom FROM salaries s 
      JOIN employees e ON s.employee_id = e.id 
    ''';
    Map<String, dynamic> params = {};
    if (before != null && before.isNotEmpty) {
      query += ' WHERE s.salary_month < :before';
      params['before'] = before;
    }
    query += ' ORDER BY s.salary_month DESC LIMIT :limit';
    params['limit'] = limit;
    
    final result = await _db.execute(query, params);
    return result.rows.map((row) => SalaryModel.fromMap(row.assoc())).toList();
  }
  
  Future<void> createSalary(Map<String, dynamic> data) async {
     await _db.execute(
      '''INSERT INTO salaries (employee_id, base_salary, bonus_amount, deductions, net_salary, salary_month, payment_status)
         VALUES (:employee_id, :base_salary, :bonus_amount, :deductions, :net_salary, :salary_month, :payment_status)
         ON DUPLICATE KEY UPDATE 
         base_salary = VALUES(base_salary), bonus_amount = VALUES(bonus_amount), deductions = VALUES(deductions),
         net_salary = VALUES(net_salary), payment_status = VALUES(payment_status)''',
      data,
    );
  }

  Future<void> updateSalaryStatus(int id, String status) async {
    String query = 'UPDATE salaries SET payment_status = :status';
    if (status == 'paid') {
      query += ', paid_at = NOW()';
    }
    query += ' WHERE id = :id';
    
    await _db.execute(
      query,
      {'id': id, 'status': status},
    );
  }

  Future<String?> getSalaryEmployeeId(int salaryId) async {
    final result = await _db.execute('SELECT employee_id FROM salaries WHERE id = :id', {'id': salaryId});
    if (result.rows.isNotEmpty) return result.rows.first.colByName('employee_id')?.toString();
    return null;
  }

  Future<int> bulkGenerateSalaries(String month, {bool fullResync = false}) async {
    final today = DateTime.now();
    // targetMonth should be the first day of the requested month
    DateTime targetMonth;
    try {
      targetMonth = DateTime.parse(month.contains('-') ? '$month-01' : month);
      targetMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    } catch (_) {
      targetMonth = DateTime(today.year, today.month, 1);
    }

    final employeesRes = await _db.execute('SELECT id, dateEmbauche, base_salary FROM employees WHERE statut = "actif"');
    
    int generatedCount = 0;

    for (final empRow in employeesRes.rows) {
      final empId = empRow.colAt(0).toString();
      final hireDateStr = empRow.colAt(1).toString();
      final baseSalary = double.tryParse(empRow.colAt(2).toString()) ?? 1200.0;

      DateTime hireDate;
      try { 
        // P2-01 FIX: Robust date parsing for various DB formats
        if (hireDateStr.contains(' ')) {
          hireDate = DateTime.parse(hireDateStr.split(' ')[0]);
        } else {
          hireDate = DateTime.parse(hireDateStr);
        }
      } catch (_) { 
        print('[HR-REPO] Warning: Failed to parse hireDate "$hireDateStr", defaulting to epoch.');
        hireDate = DateTime(2000, 1, 1); 
      }

      // If hiring date is after target month, they weren't employee yet
      if (!fullResync && hireDate.isAfter(DateTime(targetMonth.year, targetMonth.month + 1, 0))) continue;

      await _db.transaction((tx) async {
        DateTime currentMonth;
        if (fullResync) {
          currentMonth = DateTime(hireDate.year, hireDate.month, 1);
        } else {
          currentMonth = targetMonth;
        }

        int leaveDaysUsedThisYear = 0;
        int unpaidDaysDeductedThisYear = 0;
        int currentYearForQuota = currentMonth.year;

        // If we are only doing one month, we still need to know how many days were used SO FAR this year
        // for the 21-day quota logic to work.
        if (!fullResync) {
          final quotaCheckRes = await tx.execute(
            'SELECT SUM(total_days) as used FROM leave_requests '
            'WHERE employee_id = :id AND status = "approved" AND YEAR(start_date) = :year '
            'AND leave_type = "paid_leave" AND end_date < :target FOR UPDATE',
            {'id': empId, 'year': currentYearForQuota, 'target': currentMonth.toIso8601String().split('T')[0]}
          );
          leaveDaysUsedThisYear = int.tryParse(quotaCheckRes.rows.first.colByName('used')?.toString() ?? '0') ?? 0;
        }

        while (currentMonth.isBefore(today) || (currentMonth.year == today.year && currentMonth.month == today.month)) {
        if (currentMonth.year != currentYearForQuota) {
          leaveDaysUsedThisYear = 0;
          unpaidDaysDeductedThisYear = 0;
          currentYearForQuota = currentMonth.year;
        }

        final monthStart = DateTime(currentMonth.year, currentMonth.month, 1);
        final monthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0);
        final monthStr = monthStart.toIso8601String().split('T')[0];

        // 1. Fetch Attendance and Leave Types with row-level locking to prevent race conditions
        final attendanceRes = await tx.execute(
          'SELECT a.status, a.check_out, a.attendance_date, lr.leave_type '
          'FROM attendance a '
          'LEFT JOIN leave_requests lr ON a.employee_id = lr.employee_id '
          'AND a.attendance_date BETWEEN lr.start_date AND lr.end_date '
          'AND lr.status = "approved" '
          'WHERE a.employee_id = :id AND a.attendance_date BETWEEN :start AND :end FOR UPDATE',
          {'id': empId, 'start': monthStart.toIso8601String().split('T')[0], 'end': monthEnd.toIso8601String().split('T')[0]}
        );

        int presentDays = 0;
        int remoteDays = 0;
        int absentDays = 0;
        int lateCount = 0;
        int paidLeaveDaysThisMonth = 0;
        int forcedUnpaidDaysThisMonth = 0;
        double otHours = 0;

        for (final att in attendanceRes.rows) {
          final status = att.colByName('status')?.toString();
          final leaveType = att.colByName('leave_type')?.toString();
          final checkOutStr = att.colByName('check_out')?.toString();

          if (status == 'present') {
            presentDays++;
          } else if (status == 'remote') remoteDays++;
          else if (status == 'absent') absentDays++;
          else if (status == 'late') { presentDays++; lateCount++; }
          else if (status == 'leave') {
            if (leaveType == 'unpaid_leave') {
              forcedUnpaidDaysThisMonth++;
            } else if (leaveType == 'paid_leave' || leaveType == null) {
              paidLeaveDaysThisMonth++;
            }
          }

          if (checkOutStr != null && checkOutStr != 'null' && checkOutStr.isNotEmpty) {
             try {
               final checkOut = DateTime.parse(checkOutStr);
               final baseline = DateTime(checkOut.year, checkOut.month, checkOut.day, 17, 30);
               if (checkOut.isAfter(baseline)) otHours += checkOut.difference(baseline).inMinutes / 60.0;
             } catch (_) {}
          }
        }

        // 2. Calculations
        final workingDaysSetting = await _getSetting('hr_working_days_per_month', '22');
        final workingDays = double.tryParse(workingDaysSetting) ?? 22.0;
        final dailyRate = baseSalary / workingDays;
        final hourlyRate = dailyRate / 8.0;

        // PAID LEAVE QUOTA LOGIC (21 days/year)
        final totalPaidLeaveSoFar = leaveDaysUsedThisYear + paidLeaveDaysThisMonth;
        final spilloverUnpaidNeeded = (totalPaidLeaveSoFar > 21) ? (totalPaidLeaveSoFar - 21) : 0;
        
        int unpaidDueToQuotaThisMonth = spilloverUnpaidNeeded - unpaidDaysDeductedThisYear;
        if (unpaidDueToQuotaThisMonth < 0) unpaidDueToQuotaThisMonth = 0;
        if (unpaidDueToQuotaThisMonth > paidLeaveDaysThisMonth) unpaidDueToQuotaThisMonth = paidLeaveDaysThisMonth;

        unpaidDaysDeductedThisYear += unpaidDueToQuotaThisMonth;
        leaveDaysUsedThisYear += paidLeaveDaysThisMonth;

        final otAmount = otHours * hourlyRate * 1.25;
        final totalUnpaidDays = absentDays + forcedUnpaidDaysThisMonth + unpaidDueToQuotaThisMonth;
        final absenceDeduction = totalUnpaidDays * dailyRate;
        final latePenalty = lateCount * dailyRate * 0.05;

        double perfBonus = 0;
        if (presentDays + remoteDays > 15) {
            perfBonus = baseSalary * (0.05 + (0.1 * (presentDays / workingDays)));
        }
        final attendanceBonus = (absentDays == 0) ? baseSalary * 0.05 : 0.0;
        final totalBonus = perfBonus + attendanceBonus;

        final grossSalary = baseSalary + otAmount + totalBonus - absenceDeduction - latePenalty;
        
        final cnssRateSetting = await _getSetting('hr_cnss_rate', '0.0918');
        final cnssRate = double.tryParse(cnssRateSetting) ?? 0.0918;
        final cnss = grossSalary * cnssRate;
        final netSalary = grossSalary - cnss;

        // 3. Upsert
        await tx.execute(
          '''INSERT INTO salaries (employee_id, base_salary, bonus_amount, deductions, net_salary, salary_month, payment_status)
             VALUES (:id, :base, :bonus, :deduc, :net, :month, "paid")
             ON DUPLICATE KEY UPDATE 
             base_salary = VALUES(base_salary), bonus_amount = VALUES(bonus_amount), 
             deductions = VALUES(deductions), net_salary = VALUES(net_salary), payment_status = VALUES(payment_status)''',
          {
            'id': empId,
            'base': baseSalary,
            'bonus': totalBonus + otAmount,
            'deduc': cnss + absenceDeduction + latePenalty,
            'net': netSalary,
          }
        );
        currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
        if (!fullResync) break; // If not full resync, we only do one loop
        }
      }); // end of per-employee transaction
      generatedCount++;
    }
    return generatedCount;
  }


  Future<List<Map<String, dynamic>>> getBonuses(String employeeId) async {
    final result = await _db.execute(
      '''SELECT b.*, e.nom, e.prenom FROM bonuses b 
         JOIN employees e ON b.employee_id = e.id 
         WHERE b.employee_id = :employeeId 
         ORDER BY b.created_at DESC''',
      {'employeeId': employeeId},
    );
    return result.rows.map((row) {
      final map = row.assoc();
      return BonusModel.fromMap(map).toMap()..['nom'] = map['nom']..['prenom'] = map['prenom'];
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllBonuses({String? before, int limit = 50}) async {
    limit = limit > 200 ? 200 : limit;
    String query = '''
      SELECT b.*, e.nom, e.prenom FROM bonuses b 
      JOIN employees e ON b.employee_id = e.id 
    ''';
    Map<String, dynamic> params = {};
    if (before != null && before.isNotEmpty) {
      query += ' WHERE b.created_at < :before';
      params['before'] = before;
    }
    query += ' ORDER BY b.created_at DESC LIMIT :limit';
    params['limit'] = limit;

    final result = await _db.execute(query, params);
    return result.rows.map((row) {
      final map = row.assoc();
      return BonusModel.fromMap(map).toMap()..['nom'] = map['nom']..['prenom'] = map['prenom'];
    }).toList();
  }

  Future<void> grantBonus(Map<String, dynamic> data) async {
      await _db.execute(
      '''INSERT INTO bonuses (employee_id, amount, reason, bonus_type, granted_by, granted_date)
         VALUES (:employee_id, :amount, :reason, :bonus_type, :granted_by, :granted_date)''',
      data,
    );
  }

  Future<int> bulkGrantBonuses(List<String> employeeIds, Map<String, dynamic> data) async {
    if (employeeIds.isEmpty) return 0;
    
    return await _db.transaction<int>((tx) async {
      final amount = data['amount'];
      final reason = data['reason'] ?? '';
      final type = data['bonus_type'] ?? 'performance';
      final by = data['granted_by'] ?? 'SYSTEM';
      final date = data['granted_date'] ?? DateTime.now().toIso8601String().split('T')[0];

      // Idempotency check: Filter out employees that already received this exact bonus
      final existingParams = <String, dynamic>{
        'amount': amount,
        'reason': reason,
        'type': type,
        'date': date
      };
      final placeholders = [];
      for (int i = 0; i < employeeIds.length; i++) {
        final keyId = 'chk$i';
        existingParams[keyId] = employeeIds[i];
        placeholders.add(':$keyId');
      }
      final existingRes = await tx.execute(
        'SELECT employee_id FROM bonuses WHERE granted_date = :date AND reason = :reason AND amount = :amount AND bonus_type = :type AND employee_id IN (${placeholders.join(', ')}) FOR UPDATE',
        existingParams
      );
      final existingIds = existingRes.rows.map((row) => row.colByName('employee_id')?.toString()).toSet();
      
      final filteredEmployeeIds = employeeIds.where((id) => !existingIds.contains(id)).toList();
      if (filteredEmployeeIds.isEmpty) return 0;

      int totalInserted = 0;
      for (var i = 0; i < filteredEmployeeIds.length; i += 100) {
        final batchIds = filteredEmployeeIds.skip(i).take(100).toList();
        String query = 'INSERT INTO bonuses (employee_id, amount, reason, bonus_type, granted_by, granted_date) VALUES ';
        final List<String> values = [];
        final Map<String, dynamic> params = {
          'amount': amount,
          'reason': reason,
          'type': type,
          'by': by,
          'date': date
        };

        for (var j = 0; j < batchIds.length; j++) {
          final keyId = 'id$j';
          values.add('(:$keyId, :amount, :reason, :type, :by, :date)');
          params[keyId] = batchIds[j];
        }
        
        query += values.join(', ');
        final res = await tx.execute(query, params);
        totalInserted += res.affectedRows.toInt();
      }
      return totalInserted;
    });
  }

  Future<String?> generatePayslipHtmlForSalary(int salaryId, {String? logoBase64}) async {
    final result = await _db.execute(
      '''SELECT s.*, e.nom, e.prenom, e.departement, e.poste, e.dateEmbauche 
         FROM salaries s 
         JOIN employees e ON s.employee_id = e.id 
         WHERE s.id = :id''',
      {'id': salaryId},
    );
    if (result.rows.isEmpty) return null;
    
    final row = result.rows.first.assoc();
    final nom = row['nom']?.toString() ?? '';
    final prenom = row['prenom']?.toString() ?? '';
    final dept = row['departement']?.toString() ?? '';
    final poste = row['poste']?.toString() ?? '';
    final hireDate = row['dateEmbauche']?.toString() ?? '';
    
    final monthStr = row['salary_month']?.toString() ?? '';
    String monthLabel = monthStr;
    try {
      final parts = monthStr.split('-');
      if (parts.length >= 2) monthLabel = '${parts[1]}/${parts[0]}';
    } catch (_) {}

    final base = double.tryParse(row['base_salary']?.toString() ?? '0') ?? 0;
    final bonus = double.tryParse(row['bonus_amount']?.toString() ?? '0') ?? 0;
    final deduc = double.tryParse(row['deductions']?.toString() ?? '0') ?? 0;
    final net = double.tryParse(row['net_salary']?.toString() ?? '0') ?? 0;

    return '''
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Bulletin de Paie - $prenom $nom - $monthLabel</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; line-height: 1.4; padding: 20px; background: #f5f5f5; }
        .payslip-container { 
            max-width: 800px; 
            margin: 0 auto; 
            border: 1px solid #ddd; 
            padding: 30px; 
            box-shadow: 0 0 10px rgba(0,0,0,0.1); 
            background: white;
            position: relative;
            min-height: 270mm; /* A4 height approx */
            display: flex;
            flex-direction: column;
        }
        .header { display: flex; align-items: center; border-bottom: 2px solid #C9A24D; padding-bottom: 15px; margin-bottom: 20px; }
        .logo { height: 60px; margin-right: 20px; }
        .company-info { flex-grow: 1; }
        .company-info h1 { margin: 0; color: #C9A24D; font-size: 22px; }
        .company-info p { margin: 2px 0; font-size: 13px; color: #666; }
        .period { text-align: right; font-weight: bold; font-size: 16px; border-left: 2px solid #eee; padding-left: 20px; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 20px; background: #fcfcfc; padding: 15px; border-radius: 8px; border: 1px solid #eee; }
        .info-item span { font-weight: bold; color: #999; font-size: 10px; text-transform: uppercase; display: block; }
        .info-item p { margin: 2px 0 0 0; font-size: 14px; font-weight: 600; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        th { background: #f9f9f9; text-align: left; padding: 10px; border-bottom: 2px solid #eee; font-size: 13px; }
        td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; }
        .text-right { text-align: right; }
        .bold { font-weight: bold; }
        .negative { color: #d32f2f; }
        .content-wrap { flex-grow: 1; }
        .footer { margin-top: auto; display: flex; justify-content: space-between; border-top: 1px solid #eee; padding-top: 20px; }
        .summary-box { background: #fcf8ef; border: 1px solid #e9dcb9; padding: 15px; border-radius: 8px; margin-left: auto; width: 250px; }
        .summary-item { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; }
        .net-salary { font-size: 18px; color: #C9A24D; border-top: 2px solid #C9A24D; padding-top: 8px; margin-top: 8px; }

        @media print {
            body { padding: 0; margin: 0; background: white; }
            .payslip-container { 
                border: none; 
                box-shadow: none; 
                padding: 10mm; 
                max-width: 100%; 
                width: calc(100% - 20mm);
                margin: 0;
                min-height: auto;
            }
            @page {
                size: A4;
                margin: 0;
            }
            .no-print { display: none; }
        }
    </style>
</head>
<body>
    <div class="payslip-container">
        <div class="header">
            ${logoBase64 != null ? '<img src="data:image/png;base64,$logoBase64" class="logo" alt="Logo">' : ''}
            <div class="company-info">
                <h1>FS HUB ENTERPRISE</h1>
                <p>Tunis, Tunisie</p>
                <p>Matricule Fiscale: 1234567/A/B/C/000</p>
            </div>
            <div class="period">BULLETIN DE PAIE<br><small style="color: #C9A24D; font-size: 14px;">$monthLabel</small></div>
        </div>

        <div class="content-wrap">
            <div class="info-grid">
                <div class="info-item"><span>Employé</span><p>$prenom $nom</p></div>
                <div class="info-item"><span>Département</span><p>$dept</p></div>
                <div class="info-item"><span>Poste</span><p>$poste</p></div>
                <div class="info-item"><span>Date d'embauche</span><p>$hireDate</p></div>
            </div>

            <table>
                <thead>
                    <tr>
                        <th>Libellé</th>
                        <th class="text-right">Gain</th>
                        <th class="text-right">Retenu</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>Salaire de Base</td>
                        <td class="text-right">${base.toStringAsFixed(3)}</td>
                        <td class="text-right"></td>
                    </tr>
                    <tr>
                        <td>Primes & Heures sup.</td>
                        <td class="text-right">${bonus.toStringAsFixed(3)}</td>
                        <td class="text-right"></td>
                    </tr>
                    <tr>
                        <td>Total Déductions (Abs, Retard, CNSS)</td>
                        <td class="text-right"></td>
                        <td class="text-right negative">${deduc.toStringAsFixed(3)}</td>
                    </tr>
                </tbody>
            </table>
        </div>

        <div class="summary-box">
            <div class="summary-item"><span>Total Gains</span><span class="bold">${(base + bonus).toStringAsFixed(3)}</span></div>
            <div class="summary-item"><span>Total Retenues</span><span class="bold negative">${deduc.toStringAsFixed(3)}</span></div>
            <div class="summary-item net-salary"><span>NET À PAYER</span><span class="bold">${net.toStringAsFixed(3)} TND</span></div>
        </div>

        <div class="footer">
            <div>
                <p>Date d'impression : ${DateTime.now().toIso8601String().split('T')[0]}</p>
            </div>
            <div style="text-align: right;">
                <p>Signature de l'employeur</p>
                <div style="height: 60px;"></div>
                <p>Cachet FS HUB</p>
            </div>
        </div>
    </div>
</body>
</html>
    ''';
  }
}
