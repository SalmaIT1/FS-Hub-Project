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
    // Normalize date to YYYY-MM-DD before parsing if it contains a time component
    String attendanceDateString = json['attendance_date'].toString();
    if (attendanceDateString.contains('T')) {
      attendanceDateString = attendanceDateString.split('T')[0];
    }

    return Attendance(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      employeeId: json['employee_id'],
      attendanceDate: DateTime.parse(attendanceDateString),
      checkIn: json['check_in'] != null ? DateTime.parse(json['check_in']) : null,
      checkOut: json['check_out'] != null ? DateTime.parse(json['check_out']) : null,
      status: json['status'],
      workHours: json['work_hours'] != null ? double.tryParse(json['work_hours'].toString()) : 0.0,
      overtimeHours: json['overtime_hours'] != null ? double.tryParse(json['overtime_hours'].toString()) : 0.0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
