import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/client_model.dart';
import 'package:fs_hub/core/services/api_service.dart';

class ClientService {
  static final String _baseUrl = '${ApiService.baseUrl}/v1/clients';

  static Future<Map<String, dynamic>> getAllClients({
    String? type,
    String? search,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (search != null) queryParams['search'] = search;
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();
      queryParams['ngrok-skip-browser-warning'] = '1';

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load clients: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getClientById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$id?ngrok-skip-browser-warning=1'),
        headers: await ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': Client.fromJson(data),
        };
      } else {
        return {
          'success': false,
          'error': 'Client not found: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createClient(Client client) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl?ngrok-skip-browser-warning=1'),
        headers: headers,
        body: json.encode(client.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': Client.fromJson(data),
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to create client',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> updateClient(int id, Client client) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/$id?ngrok-skip-browser-warning=1'),
        headers: headers,
        body: json.encode(client.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': Client.fromJson(data),
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to update client',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteClient(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/$id?ngrok-skip-browser-warning=1'),
        headers: await ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Client deleted successfully',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to delete client',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> updateClientScore(int id, int score) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/$id/score?ngrok-skip-browser-warning=1'),
        headers: headers,
        body: json.encode({'score_credit': score}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': Client.fromJson(data),
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to update client score',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> searchClients(String query) async {
    return getAllClients(search: query);
  }
}
