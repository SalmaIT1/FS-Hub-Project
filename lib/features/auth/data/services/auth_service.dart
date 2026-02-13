import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _baseUrl = 'http://localhost:8080/v1';
  static const _storage = FlutterSecureStorage();

  // Keys for secure storage
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user_data';

  /// Login with username and password
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success']) {
        // Store tokens securely
        await _storage.write(key: _accessTokenKey, value: result['data']['accessToken']);
        await _storage.write(key: _refreshTokenKey, value: result['data']['refreshToken']);
        
        // Store user data
        await _storage.write(key: _userKey, value: jsonEncode(result['data']['user']));
        
        return {'success': true, 'message': result['message']};
      } else {
        return {'success': false, 'message': result['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Logout and clear stored tokens
  static Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }

  /// Get current user from stored data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final userDataJson = await _storage.read(key: _userKey);
    
    if (userDataJson != null) {
      return jsonDecode(userDataJson);
    }
    
    return null;
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Refresh access token using refresh token
  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      
      if (refreshToken == null) {
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success']) {
        // Update tokens
        await _storage.write(key: _accessTokenKey, value: result['data']['accessToken']);
        await _storage.write(key: _refreshTokenKey, value: result['data']['refreshToken']);
        
        return true;
      } else {
        // Refresh failed, logout user
        await logout();
        return false;
      }
    } catch (e) {
      await logout();
      return false;
    }
  }

  /// Make authenticated API request
  static Future<http.Response> authenticatedRequest(
    String endpoint,
    String method, {
    dynamic body,
  }) async {
    String? token = await getAccessToken();
    
    // If no token, return unauthorized response
    if (token == null) {
      return http.Response(
        jsonEncode({'success': false, 'message': 'Unauthorized'}),
        401,
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Try to make request with current token
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    http.Response response;
    
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(Uri.parse('$_baseUrl$endpoint'), headers: headers);
        break;
      case 'POST':
        response = await http.post(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(Uri.parse('$_baseUrl$endpoint'), headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    // If response is 401 (unauthorized), try to refresh token and retry
    if (response.statusCode == 401) {
      final refreshSuccess = await refreshToken();
      
      if (refreshSuccess) {
        // Retry request with new token
        final newToken = await getAccessToken();
        final newHeaders = {
          'Authorization': 'Bearer $newToken',
          'Content-Type': 'application/json',
        };

        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(Uri.parse('$_baseUrl$endpoint'), headers: newHeaders);
            break;
          case 'POST':
            response = await http.post(
              Uri.parse('$_baseUrl$endpoint'),
              headers: newHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              Uri.parse('$_baseUrl$endpoint'),
              headers: newHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(Uri.parse('$_baseUrl$endpoint'), headers: newHeaders);
            break;
        }
      }
    }

    return response;
  }

  /// Get greeting name for the current user
  static Future<String> getGreetingName() async {
    final user = await getCurrentUser();
    if (user != null) {
      // Try different possible field names for first name
      final firstName = user['firstName'] ?? 
                      user['prenom'] ?? 
                      user['name'] ?? 
                      user['username'] ?? 
                      'User';
      // Ensure it's a clean string
      return firstName.toString().trim();
    }
    return 'User';
  }
}