import '../models/client_model.dart';
import 'package:fs_hub/core/services/api_service.dart';

class ClientService {
  static String _query(Map<String, String?> params) {
    final q = <String, String>{};
    for (final e in params.entries) {
      if (e.value != null && e.value!.isNotEmpty) q[e.key] = e.value!;
    }
    if (q.isEmpty) return '';
    return '?${Uri(queryParameters: q).query}';
  }

  static Future<Map<String, dynamic>> getAllClients({
    String? type,
    String? search,
    int? page,
    int? limit,
  }) async {
    try {
      final result = await ApiService.get(
        '/clients${_query({
          'type': type,
          'search': search,
          if (page != null) 'page': page.toString(),
          if (limit != null) 'limit': limit.toString(),
        })}',
      );

      if (result['success'] == true) {
        final data = result['data'];
        if (data is List) {
          return {'success': true, 'data': data};
        }
        if (data is Map && data['data'] is List) {
          return {'success': true, 'data': data['data']};
        }
      }
      return {
        'success': false,
        'error': result['error'] ?? 'Failed to load clients',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getClientById(int id) async {
    try {
      final result = await ApiService.get('/clients/$id');
      if (result['success'] == true && result['data'] is Map) {
        return {
          'success': true,
          'data': Client.fromJson(result['data'] as Map<String, dynamic>),
        };
      }
      return {
        'success': false,
        'error': result['error'] ?? 'Client not found',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createClient(Client client) async {
    try {
      final result = await ApiService.post('/clients', body: client.toJson());
      if (result['success'] == true && result['data'] is Map) {
        return {
          'success': true,
          'data': Client.fromJson(result['data'] as Map<String, dynamic>),
        };
      }
      return {
        'success': false,
        'error': result['error'] ?? result['message'] ?? 'Failed to create client',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateClient(int id, Client client) async {
    try {
      final result = await ApiService.put('/clients/$id', body: client.toJson());
      if (result['success'] == true && result['data'] is Map) {
        return {
          'success': true,
          'data': Client.fromJson(result['data'] as Map<String, dynamic>),
        };
      }
      return {
        'success': false,
        'error': result['error'] ?? result['message'] ?? 'Failed to update client',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteClient(int id) async {
    try {
      final result = await ApiService.delete('/clients/$id');
      if (result['success'] == true) {
        return {
          'success': true,
          'message': result['message'] ?? 'Client deleted successfully',
        };
      }
      return {
        'success': false,
        'error': result['error'] ?? 'Failed to delete client',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateClientScore(int id, int score) async {
    try {
      final result = await ApiService.patch(
        '/clients/$id/score',
        body: {'score_credit': score},
      );
      if (result['success'] == true && result['data'] is Map) {
        return {
          'success': true,
          'data': Client.fromJson(result['data'] as Map<String, dynamic>),
        };
      }
      return {
        'success': false,
        'error': result['error'] ?? 'Failed to update client score',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> searchClients(String query) async {
    return getAllClients(search: query);
  }
}
