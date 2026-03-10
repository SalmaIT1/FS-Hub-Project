class Salary {
  final int? id;
  final String employeeId;
  final double baseSalary;
  final double? bonusAmount;
  final double? deductions;
  final double? netSalary;
  final DateTime salaryMonth;
  final String paymentStatus;
  final DateTime? paidAt;

  Salary({
    this.id,
    required this.employeeId,
    required this.baseSalary,
    this.bonusAmount,
    this.deductions,
    this.netSalary,
    required this.salaryMonth,
    required this.paymentStatus,
    this.paidAt,
  });

  factory Salary.fromJson(Map<String, dynamic> json) {
    return Salary(
      id: json['id'],
      employeeId: json['employee_id'],
      baseSalary: double.parse(json['base_salary'].toString()),
      bonusAmount: json['bonus_amount'] != null ? double.parse(json['bonus_amount'].toString()) : 0.0,
      deductions: json['deductions'] != null ? double.parse(json['deductions'].toString()) : 0.0,
      netSalary: json['net_salary'] != null ? double.parse(json['net_salary'].toString()) : null,
      salaryMonth: DateTime.parse(json['salary_month']),
      paymentStatus: json['payment_status'],
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'base_salary': baseSalary,
      'bonus_amount': bonusAmount,
      'deductions': deductions,
      'net_salary': netSalary,
      'salary_month': salaryMonth.toIso8601String(),
      'payment_status': paymentStatus,
      'paid_at': paidAt?.toIso8601String(),
    };
  }
}
