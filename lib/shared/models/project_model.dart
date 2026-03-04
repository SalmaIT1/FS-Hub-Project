class Project {
  final int? id;
  final String nom;
  final String? description;
  final int? clientId;
  final String? clientName;
  final double budget;
  final double coutEstime;
  final DateTime? dateDebut;
  final DateTime? dateFinPrevue;
  final String priorite;
  final String statut;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Project({
    this.id,
    required this.nom,
    this.description,
    this.clientId,
    this.clientName,
    this.budget = 0.0,
    this.coutEstime = 0.0,
    this.dateDebut,
    this.dateFinPrevue,
    this.priorite = 'Moyenne',
    this.statut = 'Planifié',
    this.createdAt,
    this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      clientId: json['clientId'] != null ? int.tryParse(json['clientId'].toString()) : null,
      clientName: json['clientName'] as String?,
      budget: json['budget'] != null ? double.tryParse(json['budget'].toString()) ?? 0.0 : 0.0,
      coutEstime: json['coutEstime'] != null ? double.tryParse(json['coutEstime'].toString()) ?? 0.0 : 0.0,
      dateDebut: json['dateDebut'] != null ? DateTime.tryParse(json['dateDebut'].toString()) : null,
      dateFinPrevue: json['dateFinPrevue'] != null ? DateTime.tryParse(json['dateFinPrevue'].toString()) : null,
      priorite: json['priorite'] as String? ?? 'Moyenne',
      statut: json['statut'] as String? ?? 'Planifié',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      if (description != null) 'description': description,
      if (clientId != null) 'clientId': clientId,
      'budget': budget,
      'coutEstime': coutEstime,
      if (dateDebut != null) 'dateDebut': dateDebut!.toIso8601String().split('T')[0],
      if (dateFinPrevue != null) 'dateFinPrevue': dateFinPrevue!.toIso8601String().split('T')[0],
      'priorite': priorite,
      'statut': statut,
    };
  }

  Project copyWith({
    int? id,
    String? nom,
    String? description,
    int? clientId,
    String? clientName,
    double? budget,
    double? coutEstime,
    DateTime? dateDebut,
    DateTime? dateFinPrevue,
    String? priorite,
    String? statut,
  }) {
    return Project(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      budget: budget ?? this.budget,
      coutEstime: coutEstime ?? this.coutEstime,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFinPrevue: dateFinPrevue ?? this.dateFinPrevue,
      priorite: priorite ?? this.priorite,
      statut: statut ?? this.statut,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
