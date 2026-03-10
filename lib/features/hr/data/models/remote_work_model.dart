class RemoteWork {
  final int? id;
  final String employeeId;
  final DateTime remoteDate;
  final String type;
  final String? reason;
  final String? approvedBy;
  final String status;

  RemoteWork({
    this.id,
    required this.employeeId,
    required this.remoteDate,
    required this.type,
    this.reason,
    this.approvedBy,
    required this.status,
  });

  factory RemoteWork.fromJson(Map<String, dynamic> json) {
    return RemoteWork(
      id: json['id'],
      employeeId: json['employee_id'],
      remoteDate: DateTime.parse(json['remote_date']),
      type: json['type'],
      reason: json['reason'],
      approvedBy: json['approved_by'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'remote_date': remoteDate.toIso8601String(),
      'type': type,
      'reason': reason,
      'approved_by': approvedBy,
      'status': status,
    };
  }
}
