abstract class HrRepositoryPort {
  Future<int> getUsedPaidLeaveDaysInYear(String employeeId, int year);
  Future<void> submitLeaveRequest(Map<String, dynamic> data);
  Future<String?> getLeaveRequestEmployeeId(int id);
  Future<void> updateLeaveStatus(int id, String status, String approvedBy);
}
