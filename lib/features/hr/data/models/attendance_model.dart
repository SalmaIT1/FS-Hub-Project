class Attendance {
  final int? id;
  final String employeeId;
  final DateTime attendanceDate;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final double? workHours;
  final double? overtimeHours;
  final String? notes;

  Attendance({
    this.id,
    required this.employeeId,
    required this.attendanceDate,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.workHours,
    this.overtimeHours,
    this.notes,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      employeeId: json['employee_id'],
      attendanceDate: DateTime.parse(json['attendance_date']),
      checkIn: json['check_in'] != null ? DateTime.parse(json['check_in']) : null,
      checkOut: json['check_out'] != null ? DateTime.parse(json['check_out']) : null,
      status: json['status'],
      workHours: json['work_hours']?.toDouble(),
      overtimeHours: json['overtime_hours']?.toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'attendance_date': attendanceDate.toIso8601String(),
      'check_in': checkIn?.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'status': status,
      'work_hours': workHours,
      'overtime_hours': overtimeHours,
      'notes': notes,
    };
  }
}
