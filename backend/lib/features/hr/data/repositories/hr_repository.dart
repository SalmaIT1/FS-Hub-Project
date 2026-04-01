import '../../../../shared/database/connection.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/remote_work_model.dart';
import '../models/salary_model.dart';
import '../models/bonus_model.dart';

class HrRepository {
  final _db = DBConnection.getConnection();

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
    return result.rows.map((row) => row.assoc()).toList();
  }

  Future<void> submitLeaveRequest(Map<String, dynamic> data) async {
    await _db.execute(
      '''INSERT INTO leave_requests (employee_id, leave_type, start_date, end_date, total_days, reason, status)
         VALUES (:employee_id, :leave_type, :start_date, :end_date, :total_days, :reason, :status)''',
      data,
    );
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
    return result.rows.map((row) => row.assoc()).toList();
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
      'SELECT * FROM salaries WHERE employee_id = :employeeId ORDER BY salary_month DESC',
      {'employeeId': employeeId},
    );
    return result.rows.map((row) => SalaryModel.fromMap(row.assoc())).toList();
  }
  
  Future<List<SalaryModel>> getAllSalaries() async {
    final result = await _db.execute(
      'SELECT * FROM salaries ORDER BY salary_month DESC',
      {},
    );
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

  Future<int> bulkGenerateSalaries(String month) async {
    // 1. Get all active employees with their base salary
    final employeesRes = await _db.execute("SELECT id, base_salary FROM employees WHERE statut = 'actif' AND is_deleted = FALSE");
    final employees = employeesRes.rows.map((r) => {'id': r.colAt(0), 'base': double.tryParse(r.colAt(1).toString()) ?? 0.0}).toList();

    int generatedCount = 0;
    final year = month.split('-')[0];

    for (final emp in employees) {
      final empId = emp['id'];
      final baseSalary = emp['base'] as double;

      // 2. Fetch total bonuses for this month
      final bonusRes = await _db.execute(
        "SELECT SUM(amount) as total FROM bonuses WHERE employee_id = :id AND MONTH(granted_date) = MONTH(:m) AND YEAR(granted_date) = YEAR(:m)",
        {'id': empId, 'm': '$month-01'}
      );
      final bonuses = double.tryParse(bonusRes.rows.first.colByName('total')?.toString() ?? '0') ?? 0.0;

      // 3. Fetch total approved leaves for the year so far
      final leaveRes = await _db.execute(
        "SELECT SUM(total_days) as total FROM leave_requests WHERE employee_id = :id AND status = 'approved' AND YEAR(start_date) = :year",
        {'id': empId, 'year': year}
      );
      final daysTaken = int.tryParse(leaveRes.rows.first.colByName('total')?.toString() ?? '0') ?? 0;
      
      double deductions = 0.0;
      if (daysTaken > 21) {
        // Simple formula: Deduction = (Days over 21) * (Daily rate)
        // Daily rate is approximately Salary / 26 working days
        final dailyRate = baseSalary / 26;
        final overflow = daysTaken - 21;
        deductions = overflow * dailyRate;
      }

      final netSalary = baseSalary + bonuses - deductions;

      // 4. Upsert salary record
      await _db.execute('''
        INSERT INTO salaries (employee_id, base_salary, bonus_amount, deductions, net_salary, salary_month, payment_status)
        VALUES (:id, :base, :bonus, :deduc, :net, :month, 'pending')
        ON DUPLICATE KEY UPDATE 
          base_salary = VALUES(base_salary),
          bonus_amount = VALUES(bonus_amount),
          deductions = VALUES(deductions),
          net_salary = VALUES(net_salary)
      ''', {
        'id': empId,
        'base': baseSalary,
        'bonus': bonuses,
        'deduc': deductions,
        'net': netSalary,
        'month': '$month-01'
      });
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
    return result.rows.map((row) => row.assoc()).toList();
  }

  Future<List<Map<String, dynamic>>> getAllBonuses() async {
    final result = await _db.execute(
      '''SELECT b.*, e.nom, e.prenom FROM bonuses b 
         JOIN employees e ON b.employee_id = e.id 
         ORDER BY b.created_at DESC''',
      {},
    );
    return result.rows.map((row) => row.assoc()).toList();
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
    
    // We'll prepare a multi-row insert for efficiency
    final amount = data['amount'];
    final reason = data['reason'] ?? '';
    final type = data['bonus_type'] ?? 'performance';
    final by = data['granted_by'] ?? 'SYSTEM';
    final date = data['granted_date'] ?? DateTime.now().toIso8601String().split('T')[0];

    // Due to mysql_client limitations on dynamic list size of params, 
    // we'll batch them in groups of 100 for safety, though 1 query is possible.
    int totalInserted = 0;
    for (var i = 0; i < employeeIds.length; i += 100) {
      final batchIds = employeeIds.skip(i).take(100).toList();
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
      final res = await _db.execute(query, params);
      totalInserted += res.affectedRows.toInt();
    }
    return totalInserted;
  }
}
