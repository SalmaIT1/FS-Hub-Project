import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/core/config/app_config.dart';

class RoleService {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;

  static Future<List<Map<String, dynamic>>> getAllRoles() async {
    try {
      final response = await AuthService.authenticatedRequest('/roles', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching roles: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createRole(Map<String, dynamic> roleData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/roles', // Changed from '/roles/roles' to '/roles'
        'POST',
        body: roleData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Role created successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create role',
      };
    } catch (e) {
      print('Error creating role: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateRole(int id, Map<String, dynamic> roleData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/roles/$id', // Changed from '/roles/roles/$id' to '/roles/$id'
        'PUT',
        body: roleData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Role updated successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update role',
      };
    } catch (e) {
      print('Error updating role: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteRole(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('/roles/$id', 'DELETE');

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Role deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete role',
      };
    } catch (e) {
      print('Error deleting role: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> assignPermissionsToRole(int roleId, List<int> permissionIds) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/roles/$roleId/permissions',
        'POST',
        body: {'permission_ids': permissionIds},
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Permissions assigned successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to assign permissions',
      };
    } catch (e) {
      print('Error assigning permissions: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
