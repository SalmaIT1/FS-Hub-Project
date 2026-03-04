
class ProjectMember {
  final String? id; // membership_id
  final String employeeId;
  final String nom;
  final String prenom;
  final String matricule;
  final String role;
  final String? poste;
  final String? email;
  final String? departement;
  final String? photo;
  final DateTime? joinedAt;

  ProjectMember({
    this.id,
    required this.employeeId,
    required this.nom,
    required this.prenom,
    required this.matricule,
    required this.role,
    this.poste,
    this.email,
    this.departement,
    this.photo,
    this.joinedAt,
  });

  String get displayName => '$prenom $nom';

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: json['id']?.toString(),
      employeeId: json['employeeId']?.toString() ?? json['id']?.toString() ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      matricule: json['matricule'] ?? '',
      role: json['role'] ?? 'Membre',
      poste: json['poste'],
      email: json['email'],
      departement: json['departement'],
      photo: json['photo'],
      joinedAt: json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt']) : null,
    );
  }
}
