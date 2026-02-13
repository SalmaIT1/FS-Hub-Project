import '../../../core/services/api_service.dart';
import '../../../shared/models/demand_model.dart';

class DemandService {
  /// Get all demands with optional filtering
  static Future<Map<String, dynamic>> getAllDemands({String? status, String? type}) async {
    try {
      var endpoint = '/demands/';  // Added trailing slash to match backend route pattern
      if (status != null || type != null) {
        final queryParams = <String>[];
        if (status != null) queryParams.add('status=$status');
        if (type != null) queryParams.add('type=$type');
        endpoint += '?${queryParams.join('&')}';
      }

      final result = await ApiService.get(endpoint);

      if (result['success']) {
        // Backend returns: {'success': true, 'data': demands}
        // Frontend expects: {'success': true, 'data': {'success': true, 'data': demands}}
        final data = result['data'];
        if (data['success'] != null && data['data'] != null) {
          // Handle nested response (if backend changes)
          return result; // Pass through as-is
        } else if (data is List) {
          // Handle flat response (current backend) - convert to expected format
          final demands = data
              .map((json) => Demand.fromJson(json))
              .toList();

          return {
            'success': true,
            'data': {
              'success': true,
              'data': demands,
            },
          };
        } else {
          return {
            'success': false,
            'message': 'Invalid response format',
          };
        }
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching demands: $e',
      };
    }
  }

  /// Get a specific demand by ID
  static Future<Map<String, dynamic>> getDemandById(String id) async {
    try {
      final result = await ApiService.get('/demands/$id');

      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        if (data['success'] && data['data'] != null) {
          final demand = Demand.fromJson(data['data'] as Map<String, dynamic>);

          return {
            'success': true,
            'data': demand,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Demand not found',
          };
        }
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching demand: $e',
      };
    }
  }

  /// Create a new demand
  static Future<Map<String, dynamic>> createDemand(Map<String, dynamic> demandData) async {
    try {
      final result = await ApiService.post(
        '/demands/',  // Added trailing slash to match backend route pattern
        data: demandData,
      );

      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Demand created successfully',
          'data': data['data'],
        };
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating demand: $e',
      };
    }
  }

  /// Update a demand
  static Future<Map<String, dynamic>> updateDemand(String id, Map<String, dynamic> demandData) async {
    try {
      final result = await ApiService.put(
        '/demands/$id',
        data: demandData,
      );

      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Demand updated successfully',
        };
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating demand: $e',
      };
    }
  }

  /// Update demand status
  static Future<Map<String, dynamic>> updateDemandStatus(String id, String status, {String? resolutionNotes, String? handledBy}) async {
    try {
      final updateData = {
        'status': status,
        if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
        if (handledBy != null) 'handledBy': handledBy,
      };

      final result = await ApiService.put(
        '/demands/$id/status',
        data: updateData,
      );

      if (result['success']) {
        final data = result['data'] as Map<String, dynamic>;
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Demand status updated successfully',
        };
      } else {
        return result; // Return the error from ApiService
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating demand status: $e',
      };
    }
  }
}