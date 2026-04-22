class UserModel {
  final String id;
  final String username;
  final String? role;
  final List<String>? permissions;
  final String? lastLogin;
  final String? matricule;
  final String? nom;
  final String? prenom;
  final String? email;
  final String? poste;
  final String? departement;
  
  // Client specific fields
  final String? raisonSociale;
  final String? telephone;
  final String? adresse;
  final String? matriculeFiscale;
  final String? type;
  final int? scoreCredit;

  UserModel({
    required this.id,
    required this.username,
    this.role,
    this.permissions,
    this.lastLogin,
    this.matricule,
    this.nom,
    this.prenom,
    this.email,
    this.poste,
    this.departement,
    this.raisonSociale,
    this.telephone,
    this.adresse,
    this.matriculeFiscale,
    this.type,
    this.scoreCredit,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'permissions': permissions,
      'lastLogin': lastLogin,
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'poste': poste,
      'departement': departement,
      'raisonSociale': raisonSociale,
      'telephone': telephone,
      'adresse': adresse,
      'matriculeFiscale': matriculeFiscale,
      'type': type,
      'scoreCredit': scoreCredit,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString() ?? '',
      username: map['username'] ?? '',
      role: map['role'],
      permissions: (map['permissions'] as List?)?.map((e) => e.toString()).toList().cast<String>(),
      lastLogin: map['dernierLogin']?.toString(),
      matricule: map['matricule'],
      nom: map['nom'],
      prenom: map['prenom'],
      email: map['email'],
      poste: map['poste'],
      departement: map['departement'],
      raisonSociale: map['raisonSociale'] ?? map['raison_sociale'],
      telephone: map['telephone'] ?? map['client_phone'],
      adresse: map['adresse'] ?? map['client_adresse'],
      matriculeFiscale: map['matriculeFiscale'] ?? map['matricule_fiscale'],
      type: map['type'],
      scoreCredit: int.tryParse(map['score_credit']?.toString() ?? map['scoreCredit']?.toString() ?? '0'),
    );
  }
}
