class Bonus {
  final int? id;
  final String employeeId;
  final double amount;
  final String? reason;
  final String bonusType;
  final String? grantedBy;
  final DateTime? grantedDate;

  final String? employeeNom;
  final String? employeePrenom;

  Bonus({
    this.id,
    required this.employeeId,
    required this.amount,
    this.reason,
    required this.bonusType,
    this.grantedBy,
    this.grantedDate,
    this.employeeNom,
    this.employeePrenom,
  });

  factory Bonus.fromJson(Map<String, dynamic> json) {
    return Bonus(
      id: int.tryParse(json['id']?.toString() ?? ''),
      employeeId: json['employee_id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      reason: json['reason'],
      bonusType: json['bonus_type']?.toString() ?? 'performance',
      grantedBy: json['granted_by']?.toString(),
      grantedDate: json['granted_date'] != null ? DateTime.tryParse(json['granted_date']) : null,
      employeeNom: json['nom']?.toString(),
      employeePrenom: json['prenom']?.toString(),
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
