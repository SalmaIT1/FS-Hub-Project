import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fs_hub/core/config/app_config.dart';

class AuthRemoteDatasource {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
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
        
        return data;
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  static Future<bool> logout() async {
    try {
      final token = await getAccessToken();
      if (token != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_data');
      
      return true;
    } catch (e) {
      print('Logout error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return jsonDecode(userData) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, dynamic>?> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        
        if (data['token'] != null) {
          await prefs.setString('access_token', data['token'] as String);
        }
        
        return data;
      }
      return null;
    } catch (e) {
      print('Token refresh error: $e');
      return null;
    }
  }
}
