import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/demand_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class DemandRoutes {
  late final Router router;

  DemandRoutes() {
    router = Router()
      ..get('/', _getAllDemands)
      ..get('/<id>', _getDemandById)
      ..post('/', _createDemand)
      ..put('/<id>', _updateDemand)
      ..put('/<id>/status', _updateDemandStatus)
      ..delete('/<id>', _deleteDemand);
  }

  Future<Response> _getAllDemands(Request request) async {
    try {
      final type = request.url.queryParameters['type'];
      final status = request.url.queryParameters['status'];
      final queryRequesterId = request.url.queryParameters['requesterId'];
      
      final result = await DemandService.getAllDemands(
        type: type, 
        status: status,
        requesterId: queryRequesterId,
        userRole: request.authUserRole,
        callerId: request.authUserId,
      );

      // Ensure 'data' is always a list for the frontend
      if (result['data'] == null) {
        result['data'] = [];
      }

      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('❌ ERROR in _getAllDemands: $e\n$stack');
      return Response.ok(
        jsonEncode({
          'success': false, 
          'message': 'Internal Server Error: $e',
          'data': [] // Return empty list to prevent frontend crash
        }),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  Future<Response> _getDemandById(Request request, String id) async {
    try {
      final result = await DemandService.getDemandById(id);
      if (result['success']) {
        final demand = result['data'];
        if (request.authUserRole != 'Admin' && demand['requesterId'] != request.authUserId) {
          return Response(403, body: jsonEncode({'success': false, 'message': 'Permission denied'}), headers: {'Content-Type': 'application/json'});
        }
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } else {
        return Response.notFound(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }

  Future<Response> _createDemand(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      data['requesterId'] = request.authUserId;

      final result = await DemandService.createDemand(data);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }

  Future<Response> _updateDemand(Request request, String id) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final result = await DemandService.updateDemandSecurely(id, data, request.authUserId, request.authUserRole);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } else {
        return Response(403, body: jsonEncode(result), headers: {'Content-Type': 'application/json'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }

  Future<Response> _updateDemandStatus(Request request, String id) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final result = await DemandService.updateDemandStatus(id, data, request.authUserId, request.authUserRole);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } else {
        return Response(400, body: jsonEncode(result), headers: {'Content-Type': 'application/json'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }

  Future<Response> _deleteDemand(Request request, String id) async {
    try {
      final result = await DemandService.deleteDemand(id, request.authUserId, request.authUserRole);
      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } else {
        return Response(403, body: jsonEncode(result), headers: {'Content-Type': 'application/json'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }
}
