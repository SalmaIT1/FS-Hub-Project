import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8080'; // Change to 10.0.2.2 for Android emulator
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await _storage.write(key: 'jwt', value: data['token']);
      await _storage.write(key: 'user', value: jsonEncode(data['user']));
      return {'success': true};
    } else {
      return {'success': false, 'error': data['error'] ?? 'Login failed'};
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'jwt');
    return token != null;
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'user');
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-request'),
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> confirmPasswordReset(String email, String code, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-confirm'),
      body: jsonEncode({'email': email, 'code': code, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final userJson = await _storage.read(key: 'user');
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  static Future<String> getGreetingName() async {
    final user = await getCurrentUser();
    if (user != null) {
      final firstName = user['prenom'] as String? ?? '';
      final lastName = user['nom'] as String? ?? '';
      return '$firstName $lastName'.trim();
    }
    return 'User';
  }
}
