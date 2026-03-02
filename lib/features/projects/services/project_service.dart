import 'dart:convert';
import '../../../features/auth/data/services/auth_service.dart';
import '../../../shared/models/project_model.dart';
import '../../../shared/models/project_member_model.dart';
import '../../clients/models/client_model.dart';

class ProjectService {
  static const String _baseUrl = '/projects/';

  static Future<List<Project>> getAllProjects() async {
    try {
      final response = await AuthService.authenticatedRequest(
        _baseUrl,
        'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Project.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load projects: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in ProjectService.getAllProjects: $e');
      rethrow;
    }
  }

  static Future<Project?> getProjectById(int id) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_baseUrl$id',
        'GET',
      );

      if (response.statusCode == 200) {
        return Project.fromJson(jsonDecode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      print('Error in ProjectService.getProjectById: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createProject(Project project) async {
    try {
      final response = await AuthService.authenticatedRequest(
        _baseUrl,
        'POST',
        body: project.toJson(),
      );

      return {
        'success': response.statusCode == 201,
        'message': response.statusCode == 201 
            ? 'Project created successfully' 
            : 'Failed to create project: ${response.body}',
        'data': response.statusCode == 201 ? jsonDecode(response.body) : null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProject(Project project) async {
    try {
      if (project.id == null) throw Exception('Project ID is required for update');
      
      final response = await AuthService.authenticatedRequest(
        '$_baseUrl${project.id}',
        'PUT',
        body: project.toJson(),
      );

      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200 
            ? 'Project updated successfully' 
            : 'Failed to update project: ${response.body}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteProject(int id) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_baseUrl$id',
        'DELETE',
      );

      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200 
            ? 'Project deleted successfully' 
            : 'Failed to delete project: ${response.body}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<Client>> getAvailableClients() async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/clients',
        'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Client.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error loading clients for projects: $e');
      return [];
    }
  }
  static Future<List<ProjectMember>> getProjectMembers(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('$_baseUrl$id/members', 'GET');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ProjectMember.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading project members: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addProjectMember(int projectId, String employeeId, String role) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_baseUrl$projectId/members',
        'POST',
        body: {'employeeId': employeeId, 'role': role},
      );
      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200 ? 'Member added' : jsonDecode(response.body)['error'] ?? 'Failed to add member',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> removeProjectMember(int projectId, String employeeId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_baseUrl$projectId/members/$employeeId',
        'DELETE',
      );
      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200 ? 'Member removed' : 'Failed to remove member',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<ProjectMember>> getAvailableEmployees() async {
    try {
      final response = await AuthService.authenticatedRequest('${_baseUrl}available-employees', 'GET');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // We reuse ProjectMember model for simplicity as the fields match
        return data.map((json) => ProjectMember.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading available employees: $e');
      return [];
    }
  }
}
