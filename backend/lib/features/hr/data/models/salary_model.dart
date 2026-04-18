class SalaryModel {
  final int? id;
  final String employeeId;
  final String? employeeName;
  final double baseSalary;
  final double? bonusAmount;
  final double? deductions;
  final double? netSalary;
  final DateTime salaryMonth;
  final String paymentStatus;
  final DateTime? paidAt;
  final DateTime? createdAt;

  SalaryModel({
    this.id,
    required this.employeeId,
    this.employeeName,
    required this.baseSalary,
    this.bonusAmount,
    this.deductions,
    this.netSalary,
    required this.salaryMonth,
    this.paymentStatus = 'pending',
    this.paidAt,
    this.createdAt,
  });

  factory SalaryModel.fromMap(Map<String, dynamic> map) {
    return SalaryModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      employeeId: map['employee_id'],
      employeeName: map['nom'] != null && map['prenom'] != null ? "${map['prenom']} ${map['nom']}" : map['employee_name'],
      baseSalary: double.parse(map['base_salary'].toString()),
      bonusAmount: map['bonus_amount'] != null ? double.parse(map['bonus_amount'].toString()) : 0.0,
      deductions: map['deductions'] != null ? double.parse(map['deductions'].toString()) : 0.0,
      netSalary: map['net_salary'] != null ? double.parse(map['net_salary'].toString()) : null,
      salaryMonth: DateTime.parse(map['salary_month'].toString()),
      paymentStatus: map['payment_status'] ?? 'pending',
      paidAt: map['paid_at'] != null ? DateTime.parse(map['paid_at'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'base_salary': baseSalary,
      'bonus_amount': bonusAmount,
      'deductions': deductions,
      'net_salary': netSalary,
      'salary_month': salaryMonth.toIso8601String().split('T')[0],
      'payment_status': paymentStatus,
      'paid_at': paidAt?.toIso8601String(),
    };
  }
}
