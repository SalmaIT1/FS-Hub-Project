class Task {
  final int? id;
  final int sprintId;
  final String? employeeId;
  final String titre;
  final String? description;
  final int estimationHeures;
  final int heuresReelles;
  final String statut;
  final String priorite;
  final String? sprintNom;
  final String? projectNom;

  Task({
    this.id,
    required this.sprintId,
    this.employeeId,
    required this.titre,
    this.description,
    this.estimationHeures = 0,
    this.heuresReelles = 0,
    this.statut = 'ToDo',
    this.priorite = 'Medium',
    this.sprintNom,
    this.projectNom,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      sprintId: json['sprint_id'] is int ? json['sprint_id'] : int.tryParse(json['sprint_id']?.toString() ?? '0') ?? 0,
      employeeId: json['employee_id']?.toString(),
      titre: json['titre'] ?? '',
      description: json['description'],
      estimationHeures: json['estimation_heures'] is int ? json['estimation_heures'] : int.tryParse(json['estimation_heures']?.toString() ?? '0') ?? 0,
      heuresReelles: json['heures_reelles'] is int ? json['heures_reelles'] : int.tryParse(json['heures_reelles']?.toString() ?? '0') ?? 0,
      statut: json['statut'] ?? 'ToDo',
      priorite: json['priorite'] ?? 'Medium',
      sprintNom: json['sprint_nom'],
      projectNom: json['project_nom'],
    );
  }

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
    };
  }
}
