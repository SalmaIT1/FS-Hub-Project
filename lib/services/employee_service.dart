import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee.dart';

class EmployeeService {
  static const String baseUrl = 'http://localhost:8080';

  static Future<List<Employee>> getAllEmployees() async {
    try {
      print('Fetching employees from $baseUrl/employees');
      final response = await http.get(
        Uri.parse('$baseUrl/employees'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success']) {
          final List<dynamic> data = jsonData['data'];
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
      final response = await http.get(
        Uri.parse('$baseUrl/employees/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success']) {
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
      final response = await http.post(
        Uri.parse('$baseUrl/employees'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(employee.toJson()),
      );

      final jsonData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && jsonData['success']) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Employee created successfully',
        };
      }
      
      return {
        'success': false,
        'message': jsonData['message'] ?? 'Failed to create employee',
      };
    } catch (e) {
      print('Error creating employee: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateEmployee(String id, Employee employee) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/employees/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(employee.toJson()),
      );

      final jsonData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && jsonData['success']) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Employee updated successfully',
        };
      }
      
      return {
        'success': false,
        'message': jsonData['message'] ?? 'Failed to update employee',
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
      final response = await http.delete(
        Uri.parse('$baseUrl/employees/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      final jsonData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && jsonData['success']) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Employee deleted successfully',
        };
      }
      
      return {
        'success': false,
        'message': jsonData['message'] ?? 'Failed to delete employee',
      };
    } catch (e) {
      print('Error deleting employee: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
