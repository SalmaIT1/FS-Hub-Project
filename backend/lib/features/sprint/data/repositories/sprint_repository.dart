import '../../../../shared/database/connection.dart';
import '../models/sprint_model.dart';

class SprintRepository {
  final _db = DBConnection.getConnection();

  Future<List<SprintModel>> getSprintsByProject(int projectId) async {
    final result = await _db.execute(
      'SELECT * FROM sprints WHERE projet_id = :pid ORDER BY date_debut ASC',
      {'pid': projectId}
    );

    return result.rows.map<SprintModel>((row) => SprintModel.fromMap(row.assoc())).toList();
  }

  Future<SprintModel?> getSprintById(int id) async {
    final result = await _db.execute('SELECT * FROM sprints WHERE id = :id', {'id': id});
    if (result.rows.isEmpty) return null;
    return SprintModel.fromMap(result.rows.first.assoc());
  }

  Future<void> createSprint(Map<String, dynamic> data) async {
    await _db.execute(
      '''INSERT INTO sprints (projet_id, nom, date_debut, date_fin, objectif) 
         VALUES (:pid, :nom, :debut, :fin, :obj)''',
      {
        'pid': data['projectId'],
        'nom': data['nom'],
        'debut': data['dateDebut'],
        'fin': data['dateFin'],
        'obj': data['objectif'],
      }
    );
  }

  Future<void> updateSprint(int id, Map<String, dynamic> data) async {
    await _db.execute(
      '''UPDATE sprints SET nom = :nom, date_debut = :debut, date_fin = :fin, objectif = :obj 
         WHERE id = :id''',
      {
        'id': id,
        'nom': data['nom'],
        'debut': data['dateDebut'],
        'fin': data['dateFin'],
        'obj': data['objectif'],
      }
    );
  }

  Future<void> deleteSprint(int id) async {
    await _db.execute('DELETE FROM sprints WHERE id = :id', {'id': id});
  }

  Future<bool> hasTasks(int id) async {
    final res = await _db.execute('SELECT id FROM tasks WHERE sprint_id = :id LIMIT 1', {'id': id});
    return res.rows.isNotEmpty;
  }
}
