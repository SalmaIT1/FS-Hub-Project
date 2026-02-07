import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/employee.dart';
import 'auth_service.dart';

class EmployeeService {
  /// Base URL for the backend.
  ///
  /// - On web (Docker/nginx), the backend is exposed behind `/api/` and
  ///   proxied to the `backend` container on port 8080 (see `nginx.conf`).
  /// - On mobile/desktop during local development, the backend is usually
  ///   reachable on `http://localhost:8080`.
  static final String baseUrl = 'http://localhost:8080';

  static Future<List<Employee>> getAllEmployees() async {
    try {
      final response = await AuthService.authenticatedRequest('/employees/', 'GET');

      print('Employees GET status: ${response.statusCode}');
      print('Employees GET body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          final employees = data.map((json) => Employee.fromJson(json)).toList();
          print('Successfully loaded ${employees.length} employees');
          return employees;
        }
      }

      print('Failed to fetch employees - returning empty list');
      return [];
    } catch (e) {
      print('Error fetching employees: $e');
      return [];
    }
  }

  static Future<Employee?> getEmployeeById(String id) async {
    try {
      final response = await AuthService.authenticatedRequest('/employees/$id', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          return Employee.fromJson(jsonData['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching employee: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createEmployee(Employee employee) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/employees',
        'POST',
        body: employee.toJson(),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Employee created successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create employee',
      };
    } catch (e) {
      print('Error creating employee: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateEmployee(
    String id,
    Employee employee,
  ) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/employees/$id',
        'PUT',
        body: employee.toJson(),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Employee updated successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update employee',
      };
    } catch (e) {
      print('Error updating employee: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteEmployee(String id) async {
    try {
      final response = await AuthService.authenticatedRequest('/employees/$id', 'DELETE');

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Employee deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete employee',
      };
    } catch (e) {
      print('Error deleting employee: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // ====== NOTIFICATION METHODS ======

  static Future<Map<String, dynamic>> getUserNotifications(String userId) async {
    try {
      final response = await AuthService.authenticatedRequest('/notifications/$userId', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success']) {
          return {
            'success': true,
            'data': jsonData['data'],
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Failed to fetch notifications',
      };
    } catch (e) {
      print('Error fetching notifications: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId, String userId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/notifications/$notificationId/read',
        'PUT',
        body: {'userId': userId},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success']) {
          return {
            'success': true,
            'message': jsonData['message'] ?? 'Notification marked as read',
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Failed to mark notification as read',
      };
    } catch (e) {
      print('Error marking notification as read: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead(String userId) async {
    try {
      final response = await AuthService.authenticatedRequest('/notifications/$userId/read-all', 'PUT');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success']) {
          return {
            'success': true,
            'message': jsonData['message'] ?? 'All notifications marked as read',
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Failed to mark all notifications as read',
      };
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // ====== DEMAND METHODS ======

  static Future<Map<String, dynamic>> getAllDemands({String? status, String? type}) async {
    try {
      var endpoint = '/demands/';
      if (status != null || type != null) {
        final queryParams = <String>[];
        if (status != null) queryParams.add('status=$status');
        if (type != null) queryParams.add('type=$type');
        endpoint += '?${queryParams.join('&')}';
      }

      final response = await AuthService.authenticatedRequest(endpoint, 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success']) {
          return {
            'success': true,
            'data': jsonData['data'],
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Failed to fetch demands',
      };
    } catch (e) {
      print('Error fetching demands: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Employee?> getEmployeeByEmail(String email) async {
    try {
      final employees = await getAllEmployees();
      return employees.firstWhere(
        (emp) => emp.email?.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('Employee not found'),
      );
    } catch (e) {
      print('Error fetching employee by email: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createDemand(Map<String, dynamic> demandData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/demands',
        'POST',
        body: demandData,
      );

      final jsonData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && jsonData['success']) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Demand created successfully',
          'data': jsonData['data'],
        };
      }
      
      return {
        'success': false,
        'message': jsonData['message'] ?? 'Failed to create demand',
      };
    } catch (e) {
      print('Error creating demand: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
