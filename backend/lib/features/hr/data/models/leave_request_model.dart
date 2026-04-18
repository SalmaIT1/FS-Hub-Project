class LeaveRequestModel {
  final int? id;
  final String employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int? totalDays;
  final String status;
  final String? reason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LeaveRequestModel({
    this.id,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.totalDays,
    this.status = 'pending',
    this.reason,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory LeaveRequestModel.fromMap(Map<String, dynamic> map) {
    return LeaveRequestModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      employeeId: map['employee_id'],
      leaveType: map['leave_type'],
      startDate: DateTime.parse(map['start_date'].toString()),
      endDate: DateTime.parse(map['end_date'].toString()),
      totalDays: map['total_days'] != null ? int.tryParse(map['total_days'].toString()) : null,
      status: map['status'] ?? 'pending',
      reason: map['reason'],
      approvedBy: map['approved_by'],
      approvedAt: map['approved_at'] != null ? DateTime.parse(map['approved_at'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'total_days': totalDays,
      'status': status,
      'reason': reason,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
    };
  }
}
