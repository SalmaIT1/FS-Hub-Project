import '../../../../shared/database/connection.dart';
import '../models/task_model.dart';
import '../../../sprint/data/models/sprint_model.dart';

class TaskRepository {
  final _db = DBConnection.getConnection();

  Future<List<TaskModel>> getAllTasks() async {
    final result = await _db.execute('SELECT * FROM taches ORDER BY id DESC');
    return result.rows.map<TaskModel>((row) => TaskModel.fromMap(row.assoc())).toList();
  }

  Future<List<TaskModel>> getMyTasks(String userId) async {
    final result = await _db.execute('''
      SELECT t.*, s.nom as sprint_nom, p.nom as project_nom
      FROM taches t
      JOIN sprints s ON t.sprint_id = s.id
      JOIN projets p ON s.projet_id = p.id
      WHERE t.employee_id = :userId
      ORDER BY t.priorite DESC, t.updated_at DESC
    ''', {'userId': userId});
    return result.rows.map<TaskModel>((row) => TaskModel.fromMap(row.assoc())).toList();
  }

  Future<List<TaskModel>> getTasksBySprint(int sprintId) async {
    final result = await _db.execute('''
      SELECT t.*, e.nom as employee_nom, e.prenom as employee_prenom 
      FROM taches t
      LEFT JOIN employees e ON t.employee_id = e.id
      WHERE t.sprint_id = :sid
    ''', {'sid': sprintId});
    return result.rows.map<TaskModel>((row) => TaskModel.fromMap(row.assoc())).toList();
  }

  Future<TaskModel?> getTaskById(int id) async {
    final result = await _db.execute('SELECT * FROM taches WHERE id = :id', {'id': id});
    if (result.rows.isEmpty) return null;
    return TaskModel.fromMap(result.rows.first.assoc());
  }

  Future<void> createTask(Map<String, dynamic> data) async {
    await _db.execute('''
      INSERT INTO taches (sprint_id, employee_id, titre, description, estimation_heures, statut, priorite)
      VALUES (:sid, :eid, :titre, :desc, :est, :stat, :prio)
    ''', {
      'sid': data['sprintId'],
      'eid': data['employeeId'],
      'titre': data['titre'],
      'desc': data['description'] ?? '',
      'est': data['estimationHeures'] ?? 0,
      'stat': data['statut'] ?? 'ToDo',
      'prio': data['priorite'] ?? 'Medium',
    });
  }

  Future<void> updateTask(int id, Map<String, dynamic> data) async {
    await _db.execute('''
      UPDATE taches SET 
        employee_id = :eid, titre = :titre, description = :desc, 
        estimation_heures = :est, heures_reelles = :reel, 
        statut = :stat, priorite = :prio
      WHERE id = :id
    ''', {
      'id': id,
      'eid': data['employeeId'],
      'titre': data['titre'],
      'desc': data['description'],
      'est': data['estimationHeures'],
      'reel': data['heuresReelles'],
      'stat': data['statut'],
      'prio': data['priorite'],
    });
  }

  Future<void> deleteTask(int id) async {
    await _db.execute('DELETE FROM taches WHERE id = :id', {'id': id});
  }

  Future<SprintModel?> getSprintInfo(int sprintId) async {
     final res = await _db.execute('SELECT * FROM sprints WHERE id = :sid', {'sid': sprintId});
     if (res.rows.isEmpty) return null;
     return SprintModel.fromMap(res.rows.first.assoc());
  }
}
