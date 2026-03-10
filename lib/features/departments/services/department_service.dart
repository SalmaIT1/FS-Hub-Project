import 'dart:convert';
import 'package:fs_hub/shared/models/department_model.dart';
import '../../auth/data/services/auth_service.dart';

class DepartmentService {
  static Future<List<Department>> getAllDepartments() async {
    try {
      final response = await AuthService.authenticatedRequest('/departments', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return data.map((json) => Department.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching departments: $e');
      return [];
    }
  }

  static Future<Department?> getDepartmentById(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('/departments/$id', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          return Department.fromJson(jsonData['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching department: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createDepartment(Department department) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/departments',
        'POST',
        body: department.toJson(),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Department created successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create department',
      };
    } catch (e) {
      print('Error creating department: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateDepartment(
    int id,
    Department department,
  ) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/departments/$id',
        'PUT',
        body: department.toJson(),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Department updated successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update department',
      };
    } catch (e) {
      print('Error updating department: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteDepartment(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('/departments/$id', 'DELETE');

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Department deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete department',
      };
    } catch (e) {
      print('Error deleting department: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}

