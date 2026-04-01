class EmployeeModel {
  final String id;
  final String userId;
  final String? matricule;
  final String nom;
  final String prenom;
  final String? dateNaissance;
  final String? sexe;
  final String? photo;
  final String email;
  final String? telephone;
  final String? adresse;
  final String? ville;
  final String? poste;
  final String? departement;
  final String? dateEmbauche;
  final String? typeContrat;
  final String statut;
  final String? createdAt;
  final String? updatedAt;
  final String? username;
  final String? role;

  EmployeeModel({
    required this.id,
    required this.userId,
    this.matricule,
    required this.nom,
    required this.prenom,
    this.dateNaissance,
    this.sexe,
    this.photo,
    required this.email,
    this.telephone,
    this.adresse,
    this.ville,
    this.poste,
    this.departement,
    this.dateEmbauche,
    this.typeContrat,
    required this.statut,
    this.createdAt,
    this.updatedAt,
    this.username,
    this.role,
  });

  Map<String, dynamic> toJson({bool includePrivate = false}) {
    return {
      'id': id,
      'userId': userId,
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'dateNaissance': includePrivate ? dateNaissance : null,
      'sexe': sexe,
      'photo': photo,
      'email': email,
      'telephone': includePrivate ? telephone : null,
      'adresse': includePrivate ? adresse : null,
      'ville': ville,
      'poste': poste,
      'departement': departement,
      'dateEmbauche': dateEmbauche,
      'typeContrat': typeContrat,
      'statut': statut,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'username': username,
      'role': role,
    };
  }

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      matricule: map['matricule'],
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      dateNaissance: map['dateNaissance']?.toString(),
      sexe: map['sexe'],
      photo: map['photo'],
      email: map['email'] ?? '',
      telephone: map['telephone']?.toString(),
      adresse: map['adresse'],
      ville: map['ville'],
      poste: map['poste'],
      departement: map['departement'],
      dateEmbauche: map['dateEmbauche']?.toString(),
      typeContrat: map['typeContrat'],
      statut: map['statut'] ?? 'actif',
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
      username: map['username'],
      role: map['role'],
    );
  }
}
