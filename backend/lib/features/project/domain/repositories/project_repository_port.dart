import '../../data/models/project_model.dart';

abstract class ProjectRepositoryPort {
  Future<ProjectModel?> getProjectById(int id);
  Future<bool> isMember(int projectId, String userId);
}
