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
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'clientId': clientId,
      'clientName': clientName,
      'budget': budget,
      'coutEstime': coutEstime,
      'dateDebut': dateDebut,
      'dateFinPrevue': dateFinPrevue,
      'priorite': priorite,
      'statut': statut,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
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
      priorite: map['priorite']?.toString(),
      statut: map['statut']?.toString(),
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
      'employeeId': employeeId,
      'nom': nom,
      'prenom': prenom,
      'matricule': matricule,
      'role': role,
      'poste': poste,
      'email': email,
      'departement': departement,
      'photo': photo,
      'joinedAt': joinedAt,
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
