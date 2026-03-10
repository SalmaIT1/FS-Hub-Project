import '../../data/repositories/sprint_repository.dart';
import '../../../project/data/repositories/project_repository.dart';
import '../../../../shared/services/audit_service.dart';

class SprintService {
  static final _repository = SprintRepository();
  static final _projectRepo = ProjectRepository();

  static Future<List<Map<String, dynamic>>> getSprintsByProject(int projectId, {String? callerRole, String? callerId}) async {
    // Audit check: Ensure user can see this project
    if (callerRole != 'Admin' && callerRole != 'Manager' && callerRole != 'RH' && callerId != null) {
      final isMember = await _projectRepo.isMember(projectId, callerId);
      final isOwner = await _projectRepo.isClientOwner(projectId, callerId);
      if (!isMember && !isOwner) return [];
    }

    final sprints = await _repository.getSprintsByProject(projectId);
    return sprints.map((s) => s.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getSprintById(int id, {String? callerRole, String? callerId}) async {
    final sprint = await _repository.getSprintById(id);
    if (sprint == null) return null;

    if (callerRole != 'Admin' && callerRole != 'Manager' && callerRole != 'RH' && callerId != null && sprint.projectId != null) {
      final isMember = await _projectRepo.isMember(sprint.projectId!, callerId);
      final isOwner = await _projectRepo.isClientOwner(sprint.projectId!, callerId);
      if (!isMember && !isOwner) return null;
    }

    return sprint.toJson();
  }

  static Future<void> createSprint(Map<String, dynamic> data, {String? callerId}) async {
    await _repository.createSprint(data);
    await AuditService.log(callerId ?? 'SYSTEM', 'SPRINT_CREATED', {
      'projectId': data['projet_id'],
      'nom': data['nom'],
    });
  }

  static Future<void> updateSprint(int id, Map<String, dynamic> data, {String? callerId}) async {
    await _repository.updateSprint(id, data);
    await AuditService.log(callerId ?? 'SYSTEM', 'SPRINT_UPDATED', {
      'sprintId': id,
      'fields': data.keys.toList(),
    });
  }

  static Future<Map<String, dynamic>> deleteSprint(int id, {String? callerId}) async {
    if (await _repository.hasTasks(id)) {
      return {'success': false, 'message': 'Cannot delete sprint with active tasks.'};
    }
    final sprint = await _repository.getSprintById(id);
    await _repository.deleteSprint(id);
    await AuditService.log(callerId ?? 'SYSTEM', 'SPRINT_DELETED', {
      'sprintId': id,
      'nom': sprint?.nom,
    });
    return {'success': true};
  }
}
