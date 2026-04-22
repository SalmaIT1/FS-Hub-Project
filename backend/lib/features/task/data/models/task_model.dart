class TaskModel {
  final int? id;
  final int? sprintId;
  final String? employeeId;
  final String titre;
  final String? description;
  final double estimationHeures;
  final double heuresReelles;
  final String statut;
  final String priorite;
  final String? createdAt;
  final String? updatedAt;
  final String? employeeNom;
  final String? employeePrenom;
  final String? sprintNom;
  final String? projectNom;

  TaskModel({
    this.id,
    this.sprintId,
    this.employeeId,
    required this.titre,
    this.description,
    this.estimationHeures = 0.0,
    this.heuresReelles = 0.0,
    required this.statut,
    required this.priorite,
    this.createdAt,
    this.updatedAt,
    this.employeeNom,
    this.employeePrenom,
    this.sprintNom,
    this.projectNom,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sprint_id': sprintId,
      'employee_id': employeeId,
      'titre': titre,
      'description': description,
      'estimation_heures': estimationHeures,
      'heures_reelles': heuresReelles,
      'statut': statut,
      'priorite': priorite,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'employee_nom': employeeNom,
      'employee_prenom': employeePrenom,
      'sprint_nom': sprintNom,
      'project_nom': projectNom,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      sprintId: map['sprint_id'] != null ? int.tryParse(map['sprint_id'].toString()) : null,
      employeeId: map['employee_id']?.toString(),
      titre: map['titre']?.toString() ?? '',
      description: map['description']?.toString(),
      estimationHeures: map['estimation_heures'] != null ? double.tryParse(map['estimation_heures'].toString()) ?? 0.0 : 0.0,
      heuresReelles: map['heures_reelles'] != null ? double.tryParse(map['heures_reelles'].toString()) ?? 0.0 : 0.0,
      statut: map['statut']?.toString() ?? 'ToDo',
      priorite: map['priorite']?.toString() ?? 'Medium',
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
      employeeNom: map['employee_nom']?.toString(),
      employeePrenom: map['employee_prenom']?.toString(),
      sprintNom: map['sprint_nom']?.toString(),
      projectNom: map['project_nom']?.toString(),
    );
  }
}
