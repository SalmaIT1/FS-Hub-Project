import 'dart:convert';
import 'package:fs_hub/shared/models/task_model.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';

class TaskService {
  static const String _endpoint = '/tasks';

  static Future<List<Task>> getMyTasks() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) return [];

      final response = await AuthService.authenticatedRequest(
        '$_endpoint/my-tasks',
        'GET',
        headers: {
          'X-User-Id': user['id'].toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching my tasks: $e');
      return [];
    }
  }

  static Future<List<Task>> getTasksBySprint(int sprintId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/sprint/$sprintId',
        'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching tasks by sprint: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createTask(Task task) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/',
        'POST',
        body: task.toJson(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateTask(Task task) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/${task.id}',
        'PUT',
        body: task.toJson(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteTask(int id) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/$id',
        'DELETE',
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<dynamic>> getBurndownData(int sprintId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/sprint/$sprintId/burndown',
        'GET',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching burndown data: $e');
      return [];
    }
  }
}
