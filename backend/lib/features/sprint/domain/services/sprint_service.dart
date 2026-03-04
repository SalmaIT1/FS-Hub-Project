import '../../data/repositories/sprint_repository.dart';

class SprintService {
  static final _repository = SprintRepository();

  static Future<List<Map<String, dynamic>>> getSprintsByProject(int projectId) async {
    final sprints = await _repository.getSprintsByProject(projectId);
    return sprints.map((s) => s.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getSprintById(int id) async {
    final sprint = await _repository.getSprintById(id);
    return sprint?.toJson();
  }

  static Future<void> createSprint(Map<String, dynamic> data) async {
    await _repository.createSprint(data);
  }

  static Future<void> updateSprint(int id, Map<String, dynamic> data) async {
    await _repository.updateSprint(id, data);
  }

  static Future<Map<String, dynamic>> deleteSprint(int id) async {
    if (await _repository.hasTasks(id)) {
      return {'success': false, 'message': 'Cannot delete sprint with active tasks.'};
    }
    await _repository.deleteSprint(id);
    return {'success': true};
  }
}
