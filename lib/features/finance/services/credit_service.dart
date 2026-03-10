import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/core/config/app_config.dart';

class CreditService {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;

  static Future<List<Map<String, dynamic>>> getAllCredits() async {
    try {
      final response = await AuthService.authenticatedRequest('/credits', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching credits: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getProjectCredits(int projectId) async {
    try {
      final response = await AuthService.authenticatedRequest('/credits/project/$projectId', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching project credits: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getClientCredits(int clientId) async {
    try {
      final response = await AuthService.authenticatedRequest('/credits/client/$clientId', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error fetching client credits: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createCredit(Map<String, dynamic> creditData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/credits',
        'POST',
        body: creditData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Credit created successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to create credit',
      };
    } catch (e) {
      print('Error creating credit: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateCredit(int id, Map<String, dynamic> creditData) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/credits/$id',
        'PUT',
        body: creditData,
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Credit updated successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update credit',
      };
    } catch (e) {
      print('Error updating credit: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteCredit(int id) async {
    try {
      final response = await AuthService.authenticatedRequest('/credits/$id', 'DELETE');

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Credit deleted successfully',
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to delete credit',
      };
    } catch (e) {
      print('Error deleting credit: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getCreditSummary() async {
    try {
      final response = await AuthService.authenticatedRequest('/credits/summary', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          return {
            'success': true,
            'data': jsonData['data'],
            'message': 'Credit summary retrieved successfully',
          };
        }
      }

      return {'success': false, 'data': {}};
    } catch (e) {
      print('Error fetching credit summary: $e');
      return {'success': false, 'data': {}};
    }
  }

  static Future<Map<String, dynamic>> getProjectCreditSummary(int projectId) async {
    try {
      final response = await AuthService.authenticatedRequest('/credits/project/$projectId/summary', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          return {
            'success': true,
            'data': jsonData['data'],
            'message': 'Project credit summary retrieved successfully',
          };
        }
      }

      return {'success': false, 'data': {}};
    } catch (e) {
      print('Error fetching project credit summary: $e');
      return {'success': false, 'data': {}};
    }
  }

  static Future<Map<String, dynamic>> getClientCreditSummary(int clientId) async {
    try {
      final response = await AuthService.authenticatedRequest('/credits/client/$clientId/summary', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          return {
            'success': true,
            'data': jsonData['data'],
            'message': 'Client credit summary retrieved successfully',
          };
        }
      }

      return {'success': false, 'data': {}};
    } catch (e) {
      print('Error fetching client credit summary: $e');
      return {'success': false, 'data': {}};
    }
  }

  static Future<Map<String, dynamic>> applyCreditToProject(int creditId, int projectId, double amount) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/credits/$creditId/apply/project',
        'POST',
        body: {
          'project_id': projectId,
          'amount': amount,
        },
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Credit applied successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to apply credit',
      };
    } catch (e) {
      print('Error applying credit: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> applyCreditToInvoice(int creditId, int invoiceId, double amount) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/credits/$creditId/apply-invoice',
        'POST',
        body: {
          'invoice_id': invoiceId,
          'amount': amount,
        },
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Credit applied to invoice successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to apply credit to invoice',
      };
    } catch (e) {
      print('Error applying credit to invoice: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getClientCreditLimit(int clientId) async {
    try {
      final response = await AuthService.authenticatedRequest('/credits/client/$clientId/limit', 'GET');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic> && (jsonData['success'] == true)) {
          return {
            'success': true,
            'data': jsonData['data'],
            'message': 'Client credit limit retrieved successfully',
          };
        }
      }

      return {'success': false, 'data': {}};
    } catch (e) {
      print('Error fetching client credit limit: $e');
      return {'success': false, 'data': {}};
    }
  }

  static Future<Map<String, dynamic>> updateClientCreditLimit(int clientId, double newLimit) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/credits/client/$clientId/limit',
        'PUT',
        body: {'credit_limit': newLimit},
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          jsonData is Map<String, dynamic> &&
          (jsonData['success'] == true)) {
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Credit limit updated successfully',
          'data': jsonData['data'],
        };
      }

      return {
        'success': false,
        'message': (jsonData is Map<String, dynamic> ? jsonData['message'] : null) ??
            'Failed to update credit limit',
      };
    } catch (e) {
      print('Error updating client credit limit: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
