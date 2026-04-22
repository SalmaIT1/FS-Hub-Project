import 'dart:convert';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/core/config/app_config.dart';

class ExpenseService {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;

  static Future<List<Map<String, dynamic>>> getAllProjectExpenses({int? projectId}) async {
    try {
      String endpoint = '/project-expenses';
      if (projectId != null) {
        endpoint += '?project_id=$projectId';
      }
      
      final response = await AuthService.authenticatedRequest(endpoint, 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching project expenses: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllCompanyExpenses() async {
    try {
      final response = await AuthService.authenticatedRequest('/company-expenses', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching company expenses: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createProjectExpense(Map<String, dynamic> expenseData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/project-expenses',
        'POST',
        body: expenseData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Expense created successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create expense',
      };
    } catch (e) {
      print('Error creating expense: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createCompanyExpense(Map<String, dynamic> expenseData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/company-expenses',
        'POST',
        body: expenseData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Expense created successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create expense',
      };
    } catch (e) {
      print('Error creating expense: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateProjectExpense(int id, Map<String, dynamic> expenseData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/project-expenses/$id',
        'PUT',
        body: expenseData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Expense updated successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update expense',
      };
    } catch (e) {
      print('Error updating expense: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateCompanyExpense(int id, Map<String, dynamic> expenseData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/company-expenses/$id',
        'PUT',
        body: expenseData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Expense updated successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update expense',
      };
    } catch (e) {
      print('Error updating expense: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteProjectExpense(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('/project-expenses/$id', 'DELETE');

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Expense deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete expense',
      };
    } catch (e) {
      print('Error deleting expense: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteCompanyExpense(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('/company-expenses/$id', 'DELETE');

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Expense deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete expense',
      };
    } catch (e) {
      print('Error deleting expense: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    try {
      final response = await AuthService.authenticatedRequest('/project-expenses/categories', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching expense categories: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getCompanyExpenseCategories() async {
    try {
      final response = await AuthService.authenticatedRequest('/company-expenses/categories', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching company expense categories: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createExpenseCategory(Map<String, dynamic> categoryData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/project-expenses/categories',
        'POST',
        body: categoryData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Category created successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create category',
      };
    } catch (e) {
      print('Error creating category: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createCompanyExpenseCategory(Map<String, dynamic> categoryData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/company-expenses/categories',
        'POST',
        body: categoryData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Category created successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create category',
      };
    } catch (e) {
      print('Error creating category: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getProjectExpenseSummary({int? projectId}) async {
    try {
      String endpoint = '/project-expenses/summary';
      if (projectId != null) {
        endpoint += '?project_id=$projectId';
      }
      
      final response = await AuthService.authenticatedRequest(endpoint, 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          return {
            'success': true,
            'data': jsonData['data'],
          };
        }
      }

      return {'success': false, 'data': {}};
    } catch (e) {
      print('Error fetching expense summary: $e');
      return {'success': false, 'data': {}};
    }
  }

  static Future<Map<String, dynamic>> getCompanyExpenseSummary() async {
    try {
      final response = await AuthService.authenticatedRequest('/company-expenses/summary', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          return {
            'success': true,
            'data': jsonData['data'],
          };
        }
      }

      return {'success': false, 'data': {}};
    } catch (e) {
      print('Error fetching company expense summary: $e');
      return {'success': false, 'data': {}};
    }
  }

  static Future<Map<String, dynamic>> approveExpense(String type, int id) async {
    try {
      final endpoint = '/\${type}-expenses/\$id/approve';
      final response = await AuthService.authenticatedRequest(endpoint, 'POST');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> rejectExpense(String type, int id) async {
    try {
      final endpoint = '/\${type}-expenses/\$id/reject';
      final response = await AuthService.authenticatedRequest(endpoint, 'POST');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
