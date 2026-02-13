class User {
  final String id;
  final String username;
  final String? role;
  final String? permissions;
  final String? dernierLogin;
  final String? matricule;
  final String? nom;
  final String? prenom;
  final String? email;
  final String? poste;
  final String? departement;

  User({
    required this.id,
    required this.username,
    this.role,
    this.permissions,
    this.dernierLogin,
    this.matricule,
    this.nom,
    this.prenom,
    this.email,
    this.poste,
    this.departement,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      username: json['username'] ?? '',
      role: json['role'],
      permissions: json['permissions'],
      dernierLogin: json['dernierLogin'],
      matricule: json['matricule'],
      nom: json['nom'],
      prenom: json['prenom'],
      email: json['email'],
      poste: json['poste'],
      departement: json['departement'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'permissions': permissions,
      'dernierLogin': dernierLogin,
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'poste': poste,
      'departement': departement,
    };
  }
}