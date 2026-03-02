class Sprint {
  final int? id;
  final int projectId;
  final String nom;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final String? objectif;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Sprint({
    this.id,
    required this.projectId,
    required this.nom,
    this.dateDebut,
    this.dateFin,
    this.objectif,
    this.createdAt,
    this.updatedAt,
  });

  factory Sprint.fromJson(Map<String, dynamic> json) {
    return Sprint(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      projectId: int.tryParse(json['projectId']?.toString() ?? '0') ?? 0,
      nom: json['nom'] ?? '',
      dateDebut: json['dateDebut'] != null ? DateTime.tryParse(json['dateDebut'].toString()) : null,
      dateFin: json['dateFin'] != null ? DateTime.tryParse(json['dateFin'].toString()) : null,
      objectif: json['objectif'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'projectId': projectId,
      'nom': nom,
      if (dateDebut != null) 'dateDebut': dateDebut!.toIso8601String().split('T')[0],
      if (dateFin != null) 'dateFin': dateFin!.toIso8601String().split('T')[0],
      'objectif': objectif,
    };
  }
}
