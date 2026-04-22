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
  final String? contractUrl;
  final String? contractFilename;
  final String? contractUploadedAt;
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
    this.statut = 'Planifie',
    this.contractUrl,
    this.contractFilename,
    this.contractUploadedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasContract => contractUrl != null && contractUrl!.isNotEmpty;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      clientId: json['client_id'] != null ? int.tryParse(json['client_id'].toString()) : null,
      clientName: json['client_name'] as String?,
      budget: json['budget'] != null ? double.tryParse(json['budget'].toString()) ?? 0.0 : 0.0,
      coutEstime: json['cout_estime'] != null ? double.tryParse(json['cout_estime'].toString()) ?? 0.0 : 0.0,
      dateDebut: json['date_debut'] != null ? DateTime.tryParse(json['date_debut'].toString()) : null,
      dateFinPrevue: json['date_fin_prevue'] != null ? DateTime.tryParse(json['date_fin_prevue'].toString()) : null,
      priorite: json['priorite'] as String? ?? 'Moyenne',
      statut: json['statut'] as String? ?? 'Planifie',
      contractUrl: json['contract_url'] as String?,
      contractFilename: json['contract_filename'] as String?,
      contractUploadedAt: json['contract_uploaded_at'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      if (description != null) 'description': description,
      if (clientId != null) 'client_id': clientId,
      'budget': budget,
      'cout_estime': coutEstime,
      if (dateDebut != null) 'date_debut': dateDebut!.toIso8601String().split('T')[0],
      if (dateFinPrevue != null) 'date_fin_prevue': dateFinPrevue!.toIso8601String().split('T')[0],
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
