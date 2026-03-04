import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _baseUrl = 'http://localhost:8080/v1';
  
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
          if (sessionData['accessToken'] != null) {
            await prefs.setString('access_token', sessionData['accessToken'] as String);
          }
          if (sessionData['refreshToken'] != null) {
            await prefs.setString('refresh_token', sessionData['refreshToken'] as String);
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
        if (data['token'] != null) {
          await prefs.setString('access_token', data['token']);
        }
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Token refresh failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
