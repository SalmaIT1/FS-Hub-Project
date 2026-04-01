class AttendanceModel {
  final int? id;
  final String employeeId;
  final DateTime attendanceDate;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final double? workHours;
  final double? overtimeHours;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AttendanceModel({
    this.id,
    required this.employeeId,
    required this.attendanceDate,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.workHours,
    this.overtimeHours,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      employeeId: map['employee_id'],
      attendanceDate: DateTime.parse(map['attendance_date'].toString()),
      checkIn: map['check_in'] != null ? DateTime.parse(map['check_in'].toString()) : null,
      checkOut: map['check_out'] != null ? DateTime.parse(map['check_out'].toString()) : null,
      status: map['status'] ?? 'present',
      workHours: map['work_hours'] != null ? double.tryParse(map['work_hours'].toString()) : 0.0,
      overtimeHours: map['overtime_hours'] != null ? double.tryParse(map['overtime_hours'].toString()) : 0.0,
      notes: map['notes'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'attendance_date': attendanceDate.toIso8601String().split('T')[0],
      'check_in': checkIn?.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'status': status,
      'work_hours': workHours,
      'overtime_hours': overtimeHours,
      'notes': notes,
    };
  }
}
