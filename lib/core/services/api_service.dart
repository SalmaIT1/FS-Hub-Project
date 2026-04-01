import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;
  static const String apiVersion = '/v1';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await _getToken();
    return _headers(token: token);
  }

  static Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? headers}) async {
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

  static Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body, Map<String, dynamic>? data, Map<String, String>? headers}) async {
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

  static Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body, Map<String, dynamic>? data, Map<String, String>? headers}) async {
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

  static Future<Map<String, dynamic>> delete(String endpoint, {Map<String, String>? headers}) async {
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

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': (data as Map<String, dynamic>?)?['message'] ?? 'Request failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to parse response',
        'statusCode': response.statusCode,
      };
    }
  }
}
