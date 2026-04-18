class RemoteWorkModel {
  final int? id;
  final String employeeId;
  final DateTime remoteDate;
  final String type;
  final String? reason;
  final String? approvedBy;
  final String status;
  final DateTime? createdAt;

  RemoteWorkModel({
    this.id,
    required this.employeeId,
    required this.remoteDate,
    required this.type,
    this.reason,
    this.approvedBy,
    this.status = 'pending',
    this.createdAt,
  });

  factory RemoteWorkModel.fromMap(Map<String, dynamic> map) {
    return RemoteWorkModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      employeeId: map['employee_id'],
      remoteDate: DateTime.parse(map['remote_date'].toString()),
      type: map['type'] ?? 'full_day',
      reason: map['reason'],
      approvedBy: map['approved_by'],
      status: map['status'] ?? 'pending',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'remote_date': remoteDate.toIso8601String().split('T')[0],
      'type': type,
      'reason': reason,
      'approved_by': approvedBy,
      'status': status,
    };
  }
}
