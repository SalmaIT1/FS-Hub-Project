import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fs_hub/core/config/app_config.dart';
import 'package:fs_hub/features/employees/services/employee_service.dart';

class AuthService {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;
  
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        
        // Backend returns { success, message, data: { accessToken, refreshToken, user } }
        final sessionData = data['data'] as Map<String, dynamic>?;
        if (sessionData != null) {
          // Robust mapping: check for 'accessToken' or 'token'
          final accessToken = sessionData['accessToken'] ?? sessionData['token'];
          final refreshToken = sessionData['refreshToken'];

          if (accessToken != null) {
            await prefs.setString('access_token', accessToken as String);
          }
          if (refreshToken != null) {
            await prefs.setString('refresh_token', refreshToken as String);
          }
          if (sessionData['user'] != null) {
            await prefs.setString('user_data', jsonEncode(sessionData['user']));
          }
        }
        
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return jsonDecode(userData) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<bool> hasPermission(String permission) async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    // Check if user is Admin (Admin bypass)
    final role = user['role']?.toString().toLowerCase();
    if (role == 'admin') return true;

    final permissions = user['permissions'];
    if (permissions is List) {
      return permissions.contains(permission);
    } else if (permissions is String) {
      // Fallback for legacy comma-separated string
      return permissions.split(',').contains(permission);
    }
    return false;
  }

  static Future<bool> hasRole(String roleName) async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    final role = user['role']?.toString();
    return role == roleName || role?.toLowerCase() == 'admin';
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
  }

  static Future<String> getGreetingName() async {
    final user = await getCurrentUser();
    if (user != null) {
      final prenom = user['prenom'] as String?;
      final nom = user['nom'] as String?;
      if (prenom != null || nom != null) {
        return '${prenom ?? ''} ${nom ?? ''}'.trim();
      }
      return user['username'] as String? ?? user['email'] as String? ?? 'User';
    }
    return 'User';
  }

  static Future<http.Response> authenticatedRequest(String endpoint, String method, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final token = await getToken();
    final uri = Uri.parse('$_baseUrl$endpoint');
    
    final requestHeaders = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    switch (method.toUpperCase()) {
      case 'GET':
        return http.get(uri, headers: requestHeaders);
      case 'POST':
        return http.post(uri, headers: requestHeaders, body: body != null ? jsonEncode(body) : null);
      case 'PUT':
        return http.put(uri, headers: requestHeaders, body: body != null ? jsonEncode(body) : null);
      case 'DELETE':
        return http.delete(uri, headers: requestHeaders);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  static Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await authenticatedRequest(
        '/auth/change-password',
        'POST',
        body: {'oldPassword': oldPassword, 'newPassword': newPassword},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': jsonDecode(response.body)['message'] ?? 'Failed to update password'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      final response = await authenticatedRequest(
        '/auth/settings',
        'POST',
        body: settings,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': jsonDecode(response.body)['message'] ?? 'Failed to update settings'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getUserSettings() async {
    try {
      final response = await authenticatedRequest(
        '/auth/settings',
        'GET',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': jsonDecode(response.body)['message'] ?? 'Failed to fetch settings'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      
      if (refreshToken == null) {
        return {'success': false, 'error': 'No refresh token'};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sessionData = data['data'] as Map<String, dynamic>?;
        
        if (sessionData != null) {
          final accessToken = sessionData['accessToken'] ?? sessionData['token'];
          final refreshToken = sessionData['refreshToken'];

          if (accessToken != null) {
            await prefs.setString('access_token', accessToken as String);
          }
          if (refreshToken != null) {
            await prefs.setString('refresh_token', refreshToken as String);
          }
          return {'success': true, 'data': sessionData};
        }
        return {'success': false, 'error': 'Invalid session data'};
      } else {
        return {'success': false, 'error': 'Token refresh failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteUser(String username) async {
    try {
      final response = await authenticatedRequest('/auth/users/$username', 'DELETE');
      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        
        // Also find and delete the associated employee
        try {
          final employees = await EmployeeService.getAllEmployees();
          final associatedEmployee = employees.where((emp) => emp.username == username).firstOrNull;
          
          if (associatedEmployee != null && associatedEmployee.id != null) {
            await EmployeeService.deleteEmployee(associatedEmployee.id!);
          }
        } catch (e) {
          print('Warning: Failed to delete associated employee record: $e');
          // Don't fail the user deletion if employee deletion fails
        }

        return {
          'success': true,
          'message': jsonData['message'] ?? 'User and associated employee deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete user',
      };
    } catch (e) {
      print('Error deleting user: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> adminResetUserPassword(String userId) async {
    try {
      final response = await authenticatedRequest(
        '/auth/admin/reset-user-password',
        'POST',
        body: {'userId': userId},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
