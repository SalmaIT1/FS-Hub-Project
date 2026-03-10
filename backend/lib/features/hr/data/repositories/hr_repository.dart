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
  
  Future<List<LeaveRequestModel>> getAllLeaveRequests() async {
    final result = await _db.execute(
      'SELECT * FROM leave_requests ORDER BY created_at DESC',
      {},
    );
    return result.rows.map((row) => LeaveRequestModel.fromMap(row.assoc())).toList();
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
  
  Future<List<RemoteWorkModel>> getAllRemoteWorkRequests() async {
    final result = await _db.execute(
      'SELECT * FROM remote_work ORDER BY created_at DESC',
      {},
    );
    return result.rows.map((row) => RemoteWorkModel.fromMap(row.assoc())).toList();
  }

  Future<void> submitRemoteWorkRequest(Map<String, dynamic> data) async {
    await _db.execute(
      '''INSERT INTO remote_work (employee_id, remote_date, type, reason, status)
         VALUES (:employee_id, :remote_date, :type, :reason, :status)''',
      data,
    );
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
    final result = await _db.execute('''
      INSERT INTO salaries (employee_id, base_salary, net_salary, salary_month, payment_status)
      SELECT e.id, 0, 0, :month, 'pending'
      FROM employees e
      WHERE e.statut = 'actif' AND e.is_deleted = FALSE
      ON DUPLICATE KEY UPDATE payment_status = payment_status
    ''', {'month': month});
    return result.affectedRows.toInt();
  }

  Future<List<BonusModel>> getBonuses(String employeeId) async {
    final result = await _db.execute(
      'SELECT * FROM bonuses WHERE employee_id = :employeeId ORDER BY created_at DESC',
      {'employeeId': employeeId},
    );
    return result.rows.map((row) => BonusModel.fromMap(row.assoc())).toList();
  }

  Future<void> grantBonus(Map<String, dynamic> data) async {
      await _db.execute(
      '''INSERT INTO bonuses (employee_id, amount, reason, bonus_type, granted_by, granted_date)
         VALUES (:employee_id, :amount, :reason, :bonus_type, :granted_by, :granted_date)''',
      data,
    );
  }
}
