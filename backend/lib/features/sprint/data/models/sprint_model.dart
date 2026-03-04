class SprintModel {
  final int? id;
  final int? projectId;
  final String nom;
  final String? dateDebut;
  final String? dateFin;
  final String? objectif;
  final String? createdAt;
  final String? updatedAt;

  SprintModel({
    this.id,
    this.projectId,
    required this.nom,
    this.dateDebut,
    this.dateFin,
    this.objectif,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'nom': nom,
      'dateDebut': dateDebut,
      'dateFin': dateFin,
      'objectif': objectif,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory SprintModel.fromMap(Map<String, dynamic> map) {
    return SprintModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      projectId: map['projet_id'] != null ? int.tryParse(map['projet_id'].toString()) : null,
      nom: map['nom']?.toString() ?? '',
      dateDebut: map['date_debut']?.toString(),
      dateFin: map['date_fin']?.toString(),
      objectif: map['objectif']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
