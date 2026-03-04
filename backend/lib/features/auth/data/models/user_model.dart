class UserModel {
  final String id;
  final String username;
  final String? role;
  final String? permissions;
  final String? lastLogin;
  final String? matricule;
  final String? nom;
  final String? prenom;
  final String? email;
  final String? poste;
  final String? departement;

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
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString() ?? '',
      username: map['username'] ?? '',
      role: map['role'],
      permissions: map['permissions'],
      lastLogin: map['dernierLogin']?.toString(),
      matricule: map['matricule'],
      nom: map['nom'],
      prenom: map['prenom'],
      email: map['email'],
      poste: map['poste'],
      departement: map['departement'],
    );
  }
}
