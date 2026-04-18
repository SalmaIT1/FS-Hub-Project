class RemoteWork {
  final int? id;
  final String employeeId;
  final DateTime remoteDate;
  final String type;
  final String? reason;
  final String? approvedBy;
  final String status;

  final String? employeeNom;
  final String? employeePrenom;

  RemoteWork({
    this.id,
    required this.employeeId,
    required this.remoteDate,
    required this.type,
    this.reason,
    this.approvedBy,
    required this.status,
    this.employeeNom,
    this.employeePrenom,
  });

  factory RemoteWork.fromJson(Map<String, dynamic> json) {
    return RemoteWork(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      employeeId: json['employee_id']?.toString() ?? '',
      remoteDate: DateTime.parse(json['remote_date']),
      type: json['type']?.toString() ?? 'full_day',
      reason: json['reason']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      employeeNom: json['nom']?.toString(),
      employeePrenom: json['prenom']?.toString(),
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
