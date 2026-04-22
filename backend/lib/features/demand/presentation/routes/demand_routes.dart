import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/demand_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class DemandRoutes {
  late final Router router;

  DemandRoutes() {
    final secured = Pipeline().addMiddleware(requireAuth());
    router = Router()
      ..get('/', secured.addHandler(_getAllDemands))
      ..get('/<id>', (Request r, String id) => secured.addHandler((req) => _getDemandById(req, id))(r))
      ..post('/', secured.addHandler(_createDemand))
      ..put('/<id>', (Request r, String id) => secured.addHandler((req) => _updateDemand(req, id))(r))
      ..put('/<id>/status', (Request r, String id) => secured.addHandler((req) => _updateDemandStatus(req, id))(r))
      ..delete('/<id>', (Request r, String id) => secured.addHandler((req) => _deleteDemand(req, id))(r));
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

      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e, stack) {
      print('❌ ERROR in _getAllDemands: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({
          'success': false, 
          'message': 'Internal Server Error',
          'data': []
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'}
      );
    }
  }

  Future<Response> _getDemandById(Request request, String id) async {
    try {
      final result = await DemandService.getDemandById(id);
      if (result['success']) {
        final demand = result['data'];
        if (request.authUserRole != 'Admin' && demand['requesterId'] != request.authUserId) {
          return Response(403, body: jsonEncode({'success': false, 'message': 'Permission denied'}), headers: {'Content-Type': 'application/json; charset=utf-8'});
        }
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response.notFound(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error'}));
    }
  }

  Future<Response> _createDemand(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      data['requesterId'] = request.authUserId;

      final result = await DemandService.createDemand(data);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error'}));
    }
  }

  Future<Response> _updateDemand(Request request, String id) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final result = await DemandService.updateDemandSecurely(id, data, request.authUserId, request.authUserRole);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response(403, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error'}));
    }
  }

  Future<Response> _updateDemandStatus(Request request, String id) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final result = await DemandService.updateDemandStatus(id, data, request.authUserId, request.authUserRole);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response(400, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error'}));
    }
  }

  Future<Response> _deleteDemand(Request request, String id) async {
    try {
      final result = await DemandService.deleteDemand(id, request.authUserId, request.authUserRole);
      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response(403, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error'}));
    }
  }
}
