import 'dart:convert';

class Employee {
  final String? id;
  final String matricule;
  final String nom;
  final String prenom;
  final DateTime dateNaissance;
  final String sexe;
  final String email;
  final String telephone;
  final String adresse;
  final String ville;
  final String poste;
  final String departement;
  final DateTime dateEmbauche;
  final String typeContrat;
  final String statut;
  final String? username;
  final String? role;
  final List<String>? permissions;
  final String? avatarUrl; // For display (URL or base64)
  final String? photo; // For storage (base64 string)

  Employee({
    this.id,
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    required this.sexe,
    required this.email,
    required this.telephone,
    required this.adresse,
    required this.ville,
    required this.poste,
    required this.departement,
    required this.dateEmbauche,
    required this.typeContrat,
    required this.statut,
    this.username,
    this.role,
    this.permissions,
    this.avatarUrl,
    this.photo,
  });

  String get fullName => '$prenom $nom';

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Handle permissions - can be string, array, or null
    List<String>? permissionsList;
    if (json['permissions'] != null) {
      if (json['permissions'] is String) {
        // If it's a string, try to parse it as JSON
        try {
          final decoded = jsonDecode(json['permissions']);
          if (decoded is List) {
            permissionsList = List<String>.from(decoded);
          }
        } catch (e) {
          print('Error parsing permissions: $e');
          permissionsList = null;
        }
      } else if (json['permissions'] is List) {
        permissionsList = List<String>.from(json['permissions']);
      }
    }

    return Employee(
      id: json['id']?.toString(),
      matricule: json['matricule'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      dateNaissance: json['dateNaissance'] != null 
          ? DateTime.parse(json['dateNaissance'])
          : DateTime.now(),
      sexe: json['sexe'] ?? '',
      email: json['email'] ?? '',
      telephone: json['telephone'] ?? '',
      adresse: json['adresse'] ?? '',
      ville: json['ville'] ?? '',
      poste: json['poste'] ?? '',
      departement: json['departement'] ?? '',
      dateEmbauche: json['dateEmbauche'] != null
          ? DateTime.parse(json['dateEmbauche'])
          : DateTime.now(),
      typeContrat: json['typeContrat'] ?? '',
      statut: json['statut'] ?? '',
      username: json['username'],
      role: json['role'],
      permissions: permissionsList,
      avatarUrl: json['avatarUrl'] ?? json['photo'], // Use 'photo' from backend as 'avatarUrl'
      photo: json['photo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'dateNaissance': dateNaissance.toIso8601String(),
      'sexe': sexe,
      'email': email,
      'telephone': telephone,
      'adresse': adresse,
      'ville': ville,
      'poste': poste,
      'departement': departement,
      'dateEmbauche': dateEmbauche.toIso8601String(),
      'typeContrat': typeContrat,
      'statut': statut,
      'username': username,
      'role': role,
      'permissions': permissions,
      'avatarUrl': avatarUrl,
      'photo': photo,
    };
  }

  Employee copyWith({
    String? id,
    String? matricule,
    String? nom,
    String? prenom,
    DateTime? dateNaissance,
    String? sexe,
    String? email,
    String? telephone,
    String? adresse,
    String? ville,
    String? poste,
    String? departement,
    DateTime? dateEmbauche,
    String? typeContrat,
    String? statut,
    String? username,
    String? role,
    List<String>? permissions,
    String? avatarUrl,
  }) {
    return Employee(
      id: id ?? this.id,
      matricule: matricule ?? this.matricule,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      sexe: sexe ?? this.sexe,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      ville: ville ?? this.ville,
      poste: poste ?? this.poste,
      departement: departement ?? this.departement,
      dateEmbauche: dateEmbauche ?? this.dateEmbauche,
      typeContrat: typeContrat ?? this.typeContrat,
      statut: statut ?? this.statut,
      username: username ?? this.username,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
