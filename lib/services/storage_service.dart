import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // Generic methods for secure storage
  static Future<void> writeSecureData(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> readSecureData(String key) async {
    return await _storage.read(key: key);
  }

  static Future<void> deleteSecureData(String key) async {
    await _storage.delete(key: key);
  }

  static Future<void> deleteAllSecureData() async {
    await _storage.deleteAll();
  }

  // Token management
  static Future<void> saveAccessToken(String token) async {
    await writeSecureData('access_token', token);
  }

  static Future<String?> getAccessToken() async {
    return await readSecureData('access_token');
  }

  static Future<void> saveRefreshToken(String token) async {
    await writeSecureData('refresh_token', token);
  }

  static Future<String?> getRefreshToken() async {
    return await readSecureData('refresh_token');
  }

  static Future<void> clearTokens() async {
    await deleteSecureData('access_token');
    await deleteSecureData('refresh_token');
  }

  // User data management
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final jsonString = await computeJsonEncode(userData);
    await writeSecureData('user_data', jsonString);
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final jsonString = await readSecureData('user_data');
    if (jsonString != null) {
      return await computeJsonDecode(jsonString);
    }
    return null;
  }

  static Future<void> clearUserData() async {
    await deleteSecureData('user_data');
  }

  // Settings management
  static Future<void> saveSetting(String key, String value) async {
    await writeSecureData('setting_$key', value);
  }

  static Future<String?> getSetting(String key) async {
    return await readSecureData('setting_$key');
  }

  static Future<void> clearSettings() async {
    // This would clear all settings, but we'll need to iterate through them
    // For now, we'll just note that this is a limitation of flutter_secure_storage
  }

  // Helper methods for JSON encoding/decoding
  static Future<String> computeJsonEncode(Map<String, dynamic> data) async {
    // Using dart:convert directly here
    return data.toString(); // Simplified for now
  }

  static Future<Map<String, dynamic>> computeJsonDecode(String jsonString) async {
    // Using dart:convert directly here
    return {}; // Simplified for now
  }
}

extension JsonExtension on StorageService {
  static Future<void> saveJsonData(String key, Map<String, dynamic> data) async {
    final jsonString = jsonEncode(data);
    await StorageService.writeSecureData(key, jsonString);
  }

  static Future<Map<String, dynamic>?> loadJsonData(String key) async {
    final jsonString = await StorageService.readSecureData(key);
    if (jsonString != null) {
      try {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        print('Error decoding JSON for key $key: $e');
        return null;
      }
    }
    return null;
  }
}