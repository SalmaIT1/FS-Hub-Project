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
      id: json['id'],
      nom: json['nom'],
      budgetAnnuel: (json['budgetAnnuel'] ?? 0.0).toDouble(),
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
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
