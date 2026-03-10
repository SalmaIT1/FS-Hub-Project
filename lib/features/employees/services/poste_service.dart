import 'dart:convert';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/core/config/app_config.dart';

class PosteService {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;

  static Future<List<Map<String, dynamic>>> getAllPostes() async {
    try {
      final response = await AuthService.authenticatedRequest('/postes', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching postes: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPostesByDepartment(int departementId) async {
    try {
      final response = await AuthService.authenticatedRequest('/postes?departement_id=$departementId', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching postes by department: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createPoste(Map<String, dynamic> posteData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/postes',
        'POST',
        body: posteData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Poste created successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create poste',
      };
    } catch (e) {
      print('Error creating poste: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updatePoste(int id, Map<String, dynamic> posteData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/postes/$id',
        'PUT',
        body: posteData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Poste updated successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update poste',
      };
    } catch (e) {
      print('Error updating poste: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deletePoste(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('/postes/$id', 'DELETE');

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Poste deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete poste',
      };
    } catch (e) {
      print('Error deleting poste: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
