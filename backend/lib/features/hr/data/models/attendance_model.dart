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
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      return DateTime.parse(val.toString());
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      try {
        return DateTime.parse(val.toString());
      } catch (e) {
        print('Error parsing date: $val - $e');
        return null;
      }
    }

    return AttendanceModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      employeeId: map['employee_id'],
      attendanceDate: parseDate(map['attendance_date']),
      checkIn: parseNullableDate(map['check_in']),
      checkOut: parseNullableDate(map['check_out']),
      status: map['status'] ?? 'present',
      workHours: map['work_hours'] != null ? double.tryParse(map['work_hours'].toString()) : 0.0,
      overtimeHours: map['overtime_hours'] != null ? double.tryParse(map['overtime_hours'].toString()) : 0.0,
      notes: map['notes'],
      createdAt: parseNullableDate(map['created_at']),
      updatedAt: parseNullableDate(map['updated_at']),
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
