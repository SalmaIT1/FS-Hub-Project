import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fs_hub/core/config/app_config.dart';
import 'package:fs_hub/core/security/token_storage.dart';

class AuthRemoteDatasource {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;

  static Future<String?> getAccessToken() => TokenStorage.getAccessToken();

  static Future<String?> getRefreshToken() => TokenStorage.getRefreshToken();

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
        final sessionData = data['data'] as Map<String, dynamic>?;
        if (sessionData != null) {
          final access = sessionData['accessToken']?.toString();
          final refresh = sessionData['refreshToken']?.toString();
          if (access != null && access.isNotEmpty) {
            await TokenStorage.saveTokens(
              accessToken: access,
              refreshToken: refresh,
            );
          }
          if (sessionData['user'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', jsonEncode(sessionData['user']));
          }
        }
        return data;
      }
      return null;
    } catch (e) {
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
      await TokenStorage.clearTokens();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      return true;
    } catch (e) {
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
      final refresh = await getRefreshToken();
      if (refresh == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sessionData = data['data'] as Map<String, dynamic>? ?? data;
        final access = sessionData['accessToken']?.toString() ?? data['token']?.toString();
        final newRefresh = sessionData['refreshToken']?.toString();
        if (access != null && access.isNotEmpty) {
          await TokenStorage.saveTokens(
            accessToken: access,
            refreshToken: newRefresh,
          );
        }
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
