import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores auth tokens in encrypted storage (migrates legacy SharedPreferences keys).
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';

  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _keyAccess, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefresh, value: refreshToken);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
  }

  static Future<String?> getAccessToken() async {
    var token = await _storage.read(key: _keyAccess);
    if (token != null && token.isNotEmpty) return token;

    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_keyAccess);
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: _keyAccess, value: token);
      await prefs.remove(_keyAccess);
    }
    return token;
  }

  static Future<String?> getRefreshToken() async {
    var token = await _storage.read(key: _keyRefresh);
    if (token != null && token.isNotEmpty) return token;

    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_keyRefresh);
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: _keyRefresh, value: token);
      await prefs.remove(_keyRefresh);
    }
    return token;
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
  }
}
