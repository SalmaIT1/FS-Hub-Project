import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/sprint_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class SprintRoutes {
  late final Router router;

  SprintRoutes() {
    final secured = Pipeline().addMiddleware(requireAuth());
    router = Router()
      ..get('/project/<projectId>', (Request r, String pid) => secured.addHandler((req) => _getSprintsByProject(req, pid))(r))
      ..get('/<id>', (Request r, String id) => secured.addHandler((req) => _getSprintById(req, id))(r))
      ..post('/', secured.addHandler(_createSprint))
      ..put('/<id>', (Request r, String id) => secured.addHandler((req) => _updateSprint(req, id))(r))
      ..delete('/<id>', (Request r, String id) => secured.addHandler((req) => _deleteSprint(req, id))(r));
  }

  Future<Response> _getSprintsByProject(Request request, String projectId) async {
    try {
      final pid = int.tryParse(projectId);
      if (pid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid project ID'}));

      final sprints = await SprintService.getSprintsByProject(
        pid,
        callerRole: request.authUserRole,
        callerId: request.authUserId,
      );
      return Response.ok(jsonEncode(sprints), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getSprintById(Request request, String id) async {
    try {
      final sid = int.tryParse(id);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));

      final sprint = await SprintService.getSprintById(
        sid,
        callerRole: request.authUserRole,
        callerId: request.authUserId,
      );
      if (sprint == null) return Response.notFound(jsonEncode({'error': 'Sprint not found or access denied'}));

      return Response.ok(jsonEncode(sprint), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _createSprint(Request request) async {
    try {
      final role = request.authUserRole;
      if (role != 'Admin' && role != 'Manager' && role != 'Team Lead') {
        return Response.forbidden(jsonEncode({'error': 'Only Admin, Manager or Team Lead can create sprints'}));
      }
      final payload = jsonDecode(await request.readAsString());
      await SprintService.createSprint(payload, callerId: request.authUserId);
      return Response(201, body: jsonEncode({'success': true, 'message': 'Sprint created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _updateSprint(Request request, String id) async {
    try {
      final role = request.authUserRole;
      if (role != 'Admin' && role != 'Manager' && role != 'Team Lead') {
        return Response.forbidden(jsonEncode({'error': 'Only Admin, Manager or Team Lead can modify sprints'}));
      }
      final sid = int.tryParse(id);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final payload = jsonDecode(await request.readAsString());
      await SprintService.updateSprint(sid, payload, callerId: request.authUserId);
      return Response.ok(jsonEncode({'success': true, 'message': 'Sprint updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _deleteSprint(Request request, String id) async {
    try {
      if (!request.isAdmin) return Response.forbidden(jsonEncode({'error': 'Admin only'}));
      final sid = int.tryParse(id);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));

      final res = await SprintService.deleteSprint(sid, callerId: request.authUserId);
      if (!res['success']) return Response(409, body: jsonEncode({'error': res['message']}));

      return Response.ok(jsonEncode({'success': true, 'message': 'Sprint deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}
