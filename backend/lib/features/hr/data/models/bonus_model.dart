class BonusModel {
  final int? id;
  final String employeeId;
  final double amount;
  final String? reason;
  final String bonusType;
  final String? grantedBy;
  final DateTime? grantedDate;
  final DateTime? createdAt;

  BonusModel({
    this.id,
    required this.employeeId,
    required this.amount,
    this.reason,
    required this.bonusType,
    this.grantedBy,
    this.grantedDate,
    this.createdAt,
  });

  factory BonusModel.fromMap(Map<String, dynamic> map) {
    return BonusModel(
      id: map['id'],
      employeeId: map['employee_id'],
      amount: double.parse(map['amount'].toString()),
      reason: map['reason'],
      bonusType: map['bonus_type'] ?? 'performance',
      grantedBy: map['granted_by'],
      grantedDate: map['granted_date'] != null ? DateTime.parse(map['granted_date'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'amount': amount,
      'reason': reason,
      'bonus_type': bonusType,
      'granted_by': grantedBy,
      'granted_date': grantedDate?.toIso8601String().split('T')[0],
    };
  }
}
