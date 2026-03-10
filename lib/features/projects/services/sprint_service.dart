import 'dart:convert';
import '../../../features/auth/data/services/auth_service.dart';
import 'package:fs_hub/shared/models/sprint_model.dart';

class SprintService {
  static const String _baseUrl = '/sprints/';

  static Future<List<Sprint>> getSprintsByProject(int projectId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '${_baseUrl}project/$projectId',
        'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Sprint.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error loading sprints for project $projectId: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createSprint(Sprint sprint) async {
    try {
      final response = await AuthService.authenticatedRequest(
        _baseUrl,
        'POST',
        body: sprint.toJson(),
      );

      return {
        'success': response.statusCode == 201,
        'message': response.statusCode == 201 
            ? 'Sprint created successfully' 
            : 'Failed to create sprint: ${response.body}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateSprint(Sprint sprint) async {
    try {
      if (sprint.id == null) throw Exception('Sprint ID is required');

      final response = await AuthService.authenticatedRequest(
        '$_baseUrl${sprint.id}',
        'PUT',
        body: sprint.toJson(),
      );

      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200 
            ? 'Sprint updated successfully' 
            : 'Failed to update sprint: ${response.body}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteSprint(int id) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_baseUrl$id',
        'DELETE',
      );

      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200 
            ? 'Sprint deleted successfully' 
            : 'Failed to delete sprint: ${response.body}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}

