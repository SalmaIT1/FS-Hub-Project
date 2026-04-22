class ProjectModel {
  final int? id;
  final String nom;
  final String? description;
  final int? clientId;
  final String? clientName;
  final double budget;
  final double coutEstime;
  final String? dateDebut;
  final String? dateFinPrevue;
  final String? priorite;
  final String? statut;
  final String? contractUrl;
  final String? contractFilename;
  final String? contractUploadedAt;
  final String? createdAt;
  final String? updatedAt;

  ProjectModel({
    this.id,
    required this.nom,
    this.description,
    this.clientId,
    this.clientName,
    this.budget = 0.0,
    this.coutEstime = 0.0,
    this.dateDebut,
    this.dateFinPrevue,
    this.priorite,
    this.statut,
    this.contractUrl,
    this.contractFilename,
    this.contractUploadedAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'client_id': clientId,
      'client_name': clientName,
      'budget': budget,
      'cout_estime': coutEstime,
      'date_debut': dateDebut,
      'date_fin_prevue': dateFinPrevue,
      'priorite': priorite,
      'statut': statut,
      'contract_url': contractUrl,
      'contract_filename': contractFilename,
      'contract_uploaded_at': contractUploadedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      nom: map['nom']?.toString() ?? '',
      description: map['description']?.toString(),
      clientId: map['client_id'] != null ? int.tryParse(map['client_id'].toString()) : null,
      clientName: _formatClientName(map),
      budget: map['budget'] != null ? double.tryParse(map['budget'].toString()) ?? 0.0 : 0.0,
      coutEstime: map['cout_estime'] != null ? double.tryParse(map['cout_estime'].toString()) ?? 0.0 : 0.0,
      dateDebut: map['date_debut']?.toString(),
      dateFinPrevue: map['date_fin_prevue']?.toString(),
      priorite: _normalizeString(map['priorite']),
      statut: _normalizeString(map['statut']),
      contractUrl: map['contract_url']?.toString(),
      contractFilename: map['contract_filename']?.toString(),
      contractUploadedAt: map['contract_uploaded_at']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  static String _formatClientName(Map<String, dynamic> data) {
    final rs = data['client_raison_sociale']?.toString();
    if (rs != null && rs.isNotEmpty) return rs;
    final nom = data['client_nom']?.toString() ?? '';
    final prenom = data['client_prenom']?.toString() ?? '';
    return '$nom $prenom'.trim();
  }

  static String? _normalizeString(dynamic value) {
    if (value == null) return null;
    var s = value.toString();
    // Normalize accents for consistency with frontend enums/logic
    s = s.replaceAll('é', 'e')
         .replaceAll('è', 'e')
         .replaceAll('à', 'a')
         .replaceAll('ç', 'c')
         .replaceAll('î', 'i')
         .replaceAll('ô', 'o')
         .replaceAll('û', 'u');
    return s;
  }
}

class ProjectMemberModel {
  final String? id;
  final String employeeId;
  final String nom;
  final String prenom;
  final String? matricule;
  final String? role;
  final String? poste;
  final String? email;
  final String? departement;
  final String? photo;
  final String? joinedAt;

  ProjectMemberModel({
    this.id,
    required this.employeeId,
    required this.nom,
    required this.prenom,
    this.matricule,
    this.role,
    this.poste,
    this.email,
    this.departement,
    this.photo,
    this.joinedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'nom': nom,
      'prenom': prenom,
      'matricule': matricule,
      'role': role,
      'poste': poste,
      'email': email,
      'departement': departement,
      'photo': photo,
      'joined_at': joinedAt,
    };
  }

  factory ProjectMemberModel.fromMap(Map<String, dynamic> map) {
    return ProjectMemberModel(
      id: map['membership_id']?.toString(),
      employeeId: map['id']?.toString() ?? '',
      nom: map['nom']?.toString() ?? '',
      prenom: map['prenom']?.toString() ?? '',
      matricule: map['matricule']?.toString(),
      role: map['role']?.toString(),
      poste: map['poste']?.toString(),
      email: map['email']?.toString(),
      departement: map['dept_name']?.toString(),
      photo: map['photo']?.toString(),
      joinedAt: map['joined_at']?.toString(),
    );
  }
}
