import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String _baseUrl = 'http://localhost:8080';

  /// Make an authenticated API request
  static Future<http.Response> makeRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return await AuthService.authenticatedRequest(
      endpoint,
      method,
      body: body,
    );
  }

  /// GET request
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await makeRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Request failed with status: ${response.statusCode}',
          'data': jsonDecode(response.body),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// POST request
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await makeRequest(
        endpoint: endpoint,
        method: 'POST',
        body: data,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Request failed with status: ${response.statusCode}',
          'data': jsonDecode(response.body),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await makeRequest(
        endpoint: endpoint,
        method: 'PUT',
        body: data,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Request failed with status: ${response.statusCode}',
          'data': jsonDecode(response.body),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// DELETE request
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await makeRequest(
        endpoint: endpoint,
        method: 'DELETE',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Request failed with status: ${response.statusCode}',
          'data': jsonDecode(response.body),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}