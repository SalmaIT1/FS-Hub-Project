class ExpenseModel {
  final int? id;
  final String categorie;
  final double montant;
  final DateTime dateDepense;
  final String? description;
  final int? projectId;
  final int? categoryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String status;
  final String? managerId;
  final String? hrId;
  final String? financeId;

  ExpenseModel({
    this.id,
    required this.categorie,
    required this.montant,
    required this.dateDepense,
    this.description,
    this.projectId,
    this.categoryId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.status = 'pending',
    this.managerId,
    this.hrId,
    this.financeId,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as int?,
      categorie: json['categorie'] as String,
      montant: (json['montant'] as num).toDouble(),
      dateDepense: DateTime.parse(json['date_depense'] as String),
      description: json['description'] as String?,
      projectId: json['projet_id'] as int?,
      categoryId: json['category_id'] as int?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
      status: json['status'] as String? ?? 'pending',
      managerId: json['manager_id'] as String?,
      hrId: json['hr_id'] as String?,
      financeId: json['finance_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categorie': categorie,
      'montant': montant,
      'date_depense': dateDepense.toIso8601String().split('T')[0],
      'description': description,
      'projet_id': projectId,
      'category_id': categoryId,
      'created_by': createdBy,
      'status': status,
      'manager_id': managerId,
      'hr_id': hrId,
      'finance_id': financeId,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'categorie': categorie,
      'montant': montant,
      'date_depense': dateDepense.toIso8601String().split('T')[0],
      'description': description,
      'projet_id': projectId,
      'category_id': categoryId,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final json = toCreateJson();
    if (id != null) json['id'] = id;
    return json;
  }

  ExpenseModel copyWith({
    int? id,
    String? categorie,
    double? montant,
    DateTime? dateDepense,
    String? description,
    int? projectId,
    int? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      categorie: categorie ?? this.categorie,
      montant: montant ?? this.montant,
      dateDepense: dateDepense ?? this.dateDepense,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'ExpenseModel(id: $id, categorie: $categorie, montant: $montant, dateDepense: $dateDepense)';
  }
}

class CompanyExpenseModel {
  final int? id;
  final String categorie;
  final double montant;
  final DateTime dateDepense;
  final String? description;
  final int? categoryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String status;
  final String? managerId;
  final String? hrId;
  final String? financeId;

  CompanyExpenseModel({
    this.id,
    required this.categorie,
    required this.montant,
    required this.dateDepense,
    this.description,
    this.categoryId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.status = 'pending',
    this.managerId,
    this.hrId,
    this.financeId,
  });

  factory CompanyExpenseModel.fromJson(Map<String, dynamic> json) {
    return CompanyExpenseModel(
      id: json['id'] as int?,
      categorie: json['categorie'] as String,
      montant: (json['montant'] as num).toDouble(),
      dateDepense: DateTime.parse(json['date_depense'] as String),
      description: json['description'] as String?,
      categoryId: json['category_id'] as int?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
      status: json['status'] as String? ?? 'pending',
      managerId: json['manager_id'] as String?,
      hrId: json['hr_id'] as String?,
      financeId: json['finance_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categorie': categorie,
      'montant': montant,
      'date_depense': dateDepense.toIso8601String().split('T')[0],
      'description': description,
      'category_id': categoryId,
      'created_by': createdBy,
      'status': status,
      'manager_id': managerId,
      'hr_id': hrId,
      'finance_id': financeId,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'categorie': categorie,
      'montant': montant,
      'date_depense': dateDepense.toIso8601String().split('T')[0],
      'description': description,
      'category_id': categoryId,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final json = toCreateJson();
    if (id != null) json['id'] = id;
    return json;
  }

  CompanyExpenseModel copyWith({
    int? id,
    String? categorie,
    double? montant,
    DateTime? dateDepense,
    String? description,
    int? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CompanyExpenseModel(
      id: id ?? this.id,
      categorie: categorie ?? this.categorie,
      montant: montant ?? this.montant,
      dateDepense: dateDepense ?? this.dateDepense,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'CompanyExpenseModel(id: $id, categorie: $categorie, montant: $montant, dateDepense: $dateDepense)';
  }
}

class ExpenseCategoryModel {
  final int? id;
  final String nom;
  final String? description;
  final DateTime? createdAt;

  ExpenseCategoryModel({
    this.id,
    required this.nom,
    this.description,
    this.createdAt,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] as int?,
      nom: json['nom'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'nom': nom,
      'description': description,
    };
  }

  ExpenseCategoryModel copyWith({
    int? id,
    String? nom,
    String? description,
    DateTime? createdAt,
  }) {
    return ExpenseCategoryModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ExpenseCategoryModel(id: $id, nom: $nom)';
  }
}
