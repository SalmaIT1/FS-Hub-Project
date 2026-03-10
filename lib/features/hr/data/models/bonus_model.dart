class Bonus {
  final int? id;
  final String employeeId;
  final double amount;
  final String? reason;
  final String bonusType;
  final String? grantedBy;
  final DateTime? grantedDate;

  Bonus({
    this.id,
    required this.employeeId,
    required this.amount,
    this.reason,
    required this.bonusType,
    this.grantedBy,
    this.grantedDate,
  });

  factory Bonus.fromJson(Map<String, dynamic> json) {
    return Bonus(
      id: json['id'],
      employeeId: json['employee_id'],
      amount: double.parse(json['amount'].toString()),
      reason: json['reason'],
      bonusType: json['bonus_type'],
      grantedBy: json['granted_by'],
      grantedDate: json['granted_date'] != null ? DateTime.parse(json['granted_date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'amount': amount,
      'reason': reason,
      'bonus_type': bonusType,
      'granted_by': grantedBy,
      'granted_date': grantedDate?.toIso8601String(),
    };
  }
}
