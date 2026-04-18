class LeaveRequest {
  final int? id;
  final String employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int? totalDays;
  final String status;
  final String? reason;
  final String? approvedBy;

  final String? employeeNom;
  final String? employeePrenom;

  LeaveRequest({
    this.id,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.totalDays,
    required this.status,
    this.reason,
    this.approvedBy,
    this.employeeNom,
    this.employeePrenom,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      employeeId: json['employee_id']?.toString() ?? '',
      leaveType: json['leave_type']?.toString() ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      totalDays: json['total_days'] != null ? int.tryParse(json['total_days'].toString()) : null,
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      employeeNom: json['nom']?.toString(),
      employeePrenom: json['prenom']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_days': totalDays,
      'status': status,
      'reason': reason,
      'approved_by': approvedBy,
    };
  }
}
