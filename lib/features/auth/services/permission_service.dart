import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/core/config/app_config.dart';

class PermissionService {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;

  static Future<List<Map<String, dynamic>>> getAllPermissions() async {
    try {
      final response = await AuthService.authenticatedRequest('/roles/permissions', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching permissions: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createPermission(Map<String, dynamic> permissionData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/roles/permissions',
        'POST',
        body: permissionData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Permission created successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create permission',
      };
    } catch (e) {
      print('Error creating permission: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updatePermission(int id, Map<String, dynamic> permissionData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/roles/permissions/$id',
        'PUT',
        body: permissionData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Permission updated successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update permission',
      };
    } catch (e) {
      print('Error updating permission: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deletePermission(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('/roles/permissions/$id', 'DELETE');

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Permission deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete permission',
      };
    } catch (e) {
      print('Error deleting permission: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getPermissionsByRole(int roleId) async {
    try {
      final response = await AuthService.authenticatedRequest('/roles/$roleId/permissions', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching role permissions: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPermissionsByModule(String module) async {
    try {
      final response = await AuthService.authenticatedRequest('/roles/permissions/module/$module', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching module permissions: $e');
      return [];
    }
  }
}
