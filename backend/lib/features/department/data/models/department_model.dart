class DepartmentModel {
  final int? id;
  final String nom;
  final double budgetAnnuel;
  final String? createdAt;
  final String? updatedAt;

  DepartmentModel({
    this.id,
    required this.nom,
    this.budgetAnnuel = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'budgetAnnuel': budgetAnnuel,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DepartmentModel.fromMap(Map<String, dynamic> map) {
    return DepartmentModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      nom: map['nom']?.toString() ?? '',
      budgetAnnuel: map['budget_annuel'] != null ? double.tryParse(map['budget_annuel'].toString()) ?? 0.0 : 0.0,
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
