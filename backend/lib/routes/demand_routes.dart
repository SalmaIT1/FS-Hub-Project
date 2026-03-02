import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../demand_service.dart';
import '../services/auth_service.dart';

class DemandRoutes {
  late Router router;

  DemandRoutes() {
    router = Router()
      ..get('/', _getAllDemands)
      ..get('/<id>', _getDemandById)
      ..post('/', _createDemand)
      ..put('/<id>', _updateDemand)
      ..put('/<id>/status', _updateDemandStatus)
      ..delete('/<id>', _deleteDemand);
  }

  Future<Response> _deleteDemand(Request request, String id) async {
    try {
      final token = request.headers['authorization']?.split(' ')[1];
      String? currentUserId;
      String? currentUserRole;
      
      if (token != null) {
        final tokenPayload = AuthService.verifyToken(token);
        if (tokenPayload != null) {
          currentUserId = tokenPayload['userId'];
          currentUserRole = tokenPayload['role'];
        }
      }

      if (currentUserId == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Authorization required'}));
      }

      final result = await DemandService.deleteDemand(id, currentUserId, currentUserRole);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } else {
        return Response(403, body: jsonEncode(result), headers: {'Content-Type': 'application/json'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }

  Future<Response> _getAllDemands(Request request) async {
    try {
      final token = request.headers['authorization']?.split(' ')[1];
      String? currentUserId;
      String? currentUserRole;
      
      if (token != null) {
        final tokenPayload = AuthService.verifyToken(token);
        if (tokenPayload != null) {
          currentUserId = tokenPayload['userId'];
          currentUserRole = tokenPayload['role'];
        }
      }

      final type = request.url.queryParameters['type'];
      final status = request.url.queryParameters['status'];

      final result = await DemandService.getAllDemands(
        type: type, 
        status: status,
        requesterId: currentUserId,
        userRole: currentUserRole,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getDemandById(Request request, String id) async {
    try {
      final token = request.headers['authorization']?.split(' ')[1];
      if (token == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Authorization required'}));
      }

      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Invalid token'}));
      }

      final currentUserId = payload['userId'];
      final currentUserRole = payload['role'];

      final result = await DemandService.getDemandById(id);

      if (result['success']) {
        final demand = result['data'];
        if (currentUserRole != 'Admin' && demand['requesterId'] != currentUserId) {
          return Response(403, body: jsonEncode({'success': false, 'message': 'Permission denied'}), headers: {'Content-Type': 'application/json'});
        }

        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _createDemand(Request request) async {
    try {
      final token = request.headers['authorization']?.split(' ')[1];
      if (token == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Authorization required'}));
      }

      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Invalid token'}));
      }

      final currentUserId = payload['userId'];
      final body = await request.readAsString();
      final data = jsonDecode(body);
      data['requesterId'] = currentUserId;

      final result = await DemandService.createDemand(data);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }

  Future<Response> _updateDemand(Request request, String id) async {
    try {
      final token = request.headers['authorization']?.split(' ')[1];
      if (token == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Authorization required'}));
      }

      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Invalid token'}));
      }

      final currentUserId = payload['userId'];
      final currentUserRole = payload['role'];
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final result = await DemandService.updateDemandSecurely(id, data, currentUserId, currentUserRole);

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
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final token = request.headers['authorization']?.split(' ')[1];
      
      if (token == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Authorization required'}));
      }

      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.unauthorized(jsonEncode({'success': false, 'message': 'Invalid token'}));
      }

      final currentUserId = payload['userId'];
      final currentUserRole = payload['role'];

      final result = await DemandService.updateDemandStatus(id, data, currentUserId, currentUserRole);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } else {
        return Response(400, body: jsonEncode(result), headers: {'Content-Type': 'application/json'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }
}