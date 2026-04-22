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
  final bool isOnline;
  final bool? isActive; // Database field for active/inactive status
  final String? password; // Only used for creation/update, not fetched from backend
  
  // Recruitment Documents
  final String? cinDocument;
  final String? cvDocument;
  final String? bacDocument;
  final String? degreeDocument;
  final String? transcriptsDocuments;

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
    this.isOnline = false,
    this.isActive,
    this.password,
    this.cinDocument,
    this.cvDocument,
    this.bacDocument,
    this.degreeDocument,
    this.transcriptsDocuments,
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
      dateNaissance: json['date_naissance'] != null 
          ? DateTime.parse(json['date_naissance'])
          : DateTime.now(),
      sexe: json['sexe'] ?? '',
      email: json['email'] ?? '',
      telephone: json['telephone'] ?? '',
      adresse: json['adresse'] ?? '',
      ville: json['ville'] ?? '',
      poste: json['poste'] ?? '',
      departement: json['departement'] ?? '',
      dateEmbauche: json['date_embauche'] != null
          ? DateTime.parse(json['date_embauche'])
          : DateTime.now(),
      typeContrat: json['type_contrat'] ?? '',
      statut: json['statut'] ?? '',
      username: json['username'],
      role: json['role'],
      permissions: permissionsList,
      avatarUrl: json['avatar_url'] ?? json['photo'],
      photo: json['photo'],
      isOnline: json['is_online'] == 1 || json['is_online'] == true,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      cinDocument: json['cin_document'],
      cvDocument: json['cv_document'],
      bacDocument: json['bac_document'],
      degreeDocument: json['degree_document'],
      transcriptsDocuments: json['transcripts_documents'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'date_naissance': dateNaissance.toIso8601String(),
      'sexe': sexe,
      'email': email,
      'telephone': telephone,
      'adresse': adresse,
      'ville': ville,
      'poste': poste,
      'departement': departement,
      'date_embauche': dateEmbauche.toIso8601String(),
      'type_contrat': typeContrat,
      'statut': statut,
      'username': username,
      'role': role,
      'permissions': permissions,
      'avatar_url': avatarUrl,
      'photo': photo,
      'is_online': isOnline,
      'is_active': isActive,
      'password': password,
      'cin_document': cinDocument,
      'cv_document': cvDocument,
      'bac_document': bacDocument,
      'degree_document': degreeDocument,
      'transcripts_documents': transcriptsDocuments,
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
    bool? isOnline,
    bool? isActive,
    String? cinDocument,
    String? cvDocument,
    String? bacDocument,
    String? degreeDocument,
    String? transcriptsDocuments,
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
      isOnline: isOnline ?? this.isOnline,
      isActive: isActive ?? this.isActive,
      cinDocument: cinDocument ?? this.cinDocument,
      cvDocument: cvDocument ?? this.cvDocument,
      bacDocument: bacDocument ?? this.bacDocument,
      degreeDocument: degreeDocument ?? this.degreeDocument,
      transcriptsDocuments: transcriptsDocuments ?? this.transcriptsDocuments,
    );
  }
}
