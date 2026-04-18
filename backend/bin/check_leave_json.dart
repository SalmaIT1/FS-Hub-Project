import 'package:fs_hub_backend/features/hr/domain/services/hr_service.dart';
import 'package:fs_hub_backend/shared/database/connection.dart';
import 'dart:convert';

void main() async {
  await DBConnection.initialize();
  final db = DBConnection.getConnection();
  
  // Find an employee with leave records
  final leaveRes = await db.execute("SELECT employee_id FROM attendance WHERE status = 'leave' LIMIT 1");
  if (leaveRes.rows.isEmpty) {
    print('No leave records found');
    return;
  }
  final empId = leaveRes.rows.first.colAt(0).toString();
  print('Testing for Employee ID: $empId');

  final res = await HrService.getAttendance(empId);
  if (res['success']) {
    final data = res['data'] as List;
    final leaveRecords = data.where((r) => r['status'] == 'leave').toList();
    print('Total attendance records: ${data.length}');
    print('Leave records count: ${leaveRecords.length}');
    if (leaveRecords.isNotEmpty) {
        print('Sample Leave Record JSON:');
        print(jsonEncode(leaveRecords.first));
    }
  } else {
    print('Error: ${res['message']}');
  }
  
  await DBConnection.close();
}
