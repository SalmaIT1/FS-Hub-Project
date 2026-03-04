import '../../data/repositories/project_repository.dart';
import '../../../../core/services/data_integrity_service.dart';

class ProjectService {
  static final _repository = ProjectRepository();

  static Future<List<Map<String, dynamic>>> getAllProjects() async {
    final projects = await _repository.getAllProjects();
    return projects.map((p) => p.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getProjectById(int id) async {
    final project = await _repository.getProjectById(id);
    return project?.toJson();
  }

  static Future<int> createProject(Map<String, dynamic> data) async {
    return await _repository.createProject(data);
  }

  static Future<void> updateProject(int id, Map<String, dynamic> data) async {
    await _repository.updateProject(id, data);
  }

  static Future<Map<String, dynamic>> deleteProject(int id) async {
    if (await _repository.hasActiveSprints(id)) {
      return {'success': false, 'message': 'Cannot delete project with active sprints.'};
    }
    await _repository.deleteProject(id);
    return {'success': true};
  }

  static Future<void> checkDeadlines() async {
    await DataIntegrityService.checkDeadlines();
  }

  static Future<List<Map<String, dynamic>>> getAvailableEmployees() async {
    return await _repository.getAvailableEmployees();
  }

  static Future<List<Map<String, dynamic>>> getProjectMembers(int projectId) async {
    final members = await _repository.getProjectMembers(projectId);
    return members.map((m) => m.toJson()).toList();
  }

  static Future<void> addProjectMember(int projectId, String employeeId, {String role = 'Membre'}) async {
    await _repository.addProjectMember(projectId, employeeId, role);
  }

  static Future<void> removeProjectMember(int projectId, String employeeId) async {
    await _repository.removeProjectMember(projectId, employeeId);
  }
}
