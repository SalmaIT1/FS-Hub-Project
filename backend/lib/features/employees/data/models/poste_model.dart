class PosteModel {
  final int? id;
  final String nom;
  final String? description;
  final int? departementId;
  final DateTime? createdAt;

  PosteModel({
    this.id,
    required this.nom,
    this.description,
    this.departementId,
    this.createdAt,
  });

  factory PosteModel.fromJson(Map<String, dynamic> json) {
    return PosteModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      nom: (json['nom'] ?? 'Sans Nom').toString(),
      description: json['description']?.toString(),
      departementId: json['departement_id'] != null ? int.tryParse(json['departement_id'].toString()) : null,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'departement_id': departementId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'nom': nom,
      'description': description,
      'departement_id': departementId,
    };
  }

  PosteModel copyWith({
    int? id,
    String? nom,
    String? description,
    int? departementId,
    DateTime? createdAt,
  }) {
    return PosteModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      departementId: departementId ?? this.departementId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'PosteModel(id: $id, nom: $nom, departementId: $departementId)';
  }
}
