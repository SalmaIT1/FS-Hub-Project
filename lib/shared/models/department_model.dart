class Department {
  final int? id;
  final String nom;
  final double budgetAnnuel;
  final String? createdAt;
  final String? updatedAt;

  Department({
    this.id,
    required this.nom,
    this.budgetAnnuel = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      nom: json['nom']?.toString() ?? '',
      // Backend returns snake_case keys (budget_annuel), camelCase is used internally
      budgetAnnuel: (json['budget_annuel'] ?? json['budgetAnnuel'] ?? 0.0) is String
          ? double.tryParse((json['budget_annuel'] ?? json['budgetAnnuel']).toString()) ?? 0.0
          : ((json['budget_annuel'] ?? json['budgetAnnuel'] ?? 0.0) as num).toDouble(),
      createdAt: (json['created_at'] ?? json['createdAt'])?.toString(),
      updatedAt: (json['updated_at'] ?? json['updatedAt'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'budgetAnnuel': budgetAnnuel,
    };
  }

  Department copyWith({
    int? id,
    String? nom,
    double? budgetAnnuel,
    String? createdAt,
    String? updatedAt,
  }) {
    return Department(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      budgetAnnuel: budgetAnnuel ?? this.budgetAnnuel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
