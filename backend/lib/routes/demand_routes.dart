import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../demand_service.dart';
import '../services/auth_service.dart';

class DemandRoutes {
  late final Router router;

  DemandRoutes() {
    router = Router()
      ..get('/', _getAllDemands)
      ..get('/<id>', _getDemandById)
      ..post('/', _createDemand)
      ..put('/<id>', _updateDemand)
      ..put('/<id>/status', _updateDemandStatus);
  }

  Future<Response> _getAllDemands(Request request) async {
    try {
      // Parse query parameters
      final type = request.url.queryParameters['type'];
      final status = request.url.queryParameters['status'];

      final result = await DemandService.getAllDemands(type: type, status: status);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
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
      final result = await DemandService.getDemandById(id);

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

  Future<Response> _createDemand(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final result = await DemandService.createDemand(data);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
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

  Future<Response> _updateDemand(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final result = await DemandService.updateDemand(id, data);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
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

  Future<Response> _updateDemandStatus(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      // Extract token from headers and verify it
      final token = request.headers['authorization']?.split(' ')[1];
      String? currentUserId;
      
      if (token != null) {
        final tokenPayload = AuthService.verifyToken(token);
        if (tokenPayload != null) {
          currentUserId = tokenPayload['userId'];
        } else {
          return Response.unauthorized(
            jsonEncode({'success': false, 'message': 'Invalid or expired token'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } else {
        return Response.unauthorized(
          jsonEncode({'success': false, 'message': 'Authorization token required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // This specifically handles status updates with authorization check
      final result = await DemandService.updateDemandStatus(id, data, currentUserId);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
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
}