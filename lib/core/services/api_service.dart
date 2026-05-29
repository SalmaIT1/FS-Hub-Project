import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../security/token_storage.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;
  static const String apiVersion = '/v1';

  static Future<String?> _getToken() => TokenStorage.getAccessToken();

  static Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await _getToken();
    return _headers(token: token);
  }

  /// Unwraps backend `{ success, data, message }` into a consistent client shape.
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'success': false,
            'error': decoded['message'] ?? 'Request failed',
            'statusCode': response.statusCode,
            'data': decoded,
          };
        }
        return {
          'success': false,
          'error': 'Request failed',
          'statusCode': response.statusCode,
        };
      }

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('success')) {
          final ok = decoded['success'] != false;
          return {
            'success': ok,
            if (ok) 'data': decoded['data'] ?? decoded,
            if (!ok) 'error': decoded['message'] ?? 'Request failed',
            if (decoded['message'] != null) 'message': decoded['message'],
            'statusCode': response.statusCode,
          };
        }
        return {'success': true, 'data': decoded, 'statusCode': response.statusCode};
      }

      if (decoded is List) {
        return {'success': true, 'data': decoded, 'statusCode': response.statusCode};
      }

      return {'success': true, 'data': decoded, 'statusCode': response.statusCode};
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to parse response',
        'statusCode': response.statusCode,
      };
    }
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion$endpoint'),
        headers: {..._headers(token: token), ...?headers},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion$endpoint'),
        headers: {..._headers(token: token), ...?headers},
        body: jsonEncode(data ?? body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$baseUrl$apiVersion$endpoint'),
        headers: {..._headers(token: token), ...?headers},
        body: jsonEncode(data ?? body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl$apiVersion$endpoint'),
        headers: {..._headers(token: token), ...?headers},
        body: jsonEncode(data ?? body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl$apiVersion$endpoint'),
        headers: {..._headers(token: token), ...?headers},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
