import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fs_hub/core/config/app_config.dart';
import 'package:fs_hub/features/auth/data/datasources/auth_remote_datasource.dart';

class AiService {
  static final String _baseUrl = AppConfig.apiV1BaseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthRemoteDatasource.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> getProjectRisks() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ai/project-risks'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      }
    } catch (e) {
      print('AiService Error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPaymentBehavior() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ai/payment-behavior'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      }
    } catch (e) {
      print('AiService Error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getStrategicInsights() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ai/strategic-insights'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      }
    } catch (e) {
      print('AiService Error: $e');
    }
    return null;
  }
}
