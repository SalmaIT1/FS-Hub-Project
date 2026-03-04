import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/sprint_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class SprintRoutes {
  late final Router router;

  SprintRoutes() {
    router = Router()
      ..get('/project/<projectId>', _getSprintsByProject)
      ..get('/<id>', _getSprintById)
      ..post('/', _createSprint)
      ..put('/<id>', _updateSprint)
      ..delete('/<id>', _deleteSprint);
  }

  Future<Response> _getSprintsByProject(Request request, String projectId) async {
    try {
      final pid = int.tryParse(projectId);
      if (pid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid project ID'}));

      final sprints = await SprintService.getSprintsByProject(pid);
      return Response.ok(jsonEncode(sprints), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getSprintById(Request request, String id) async {
    try {
      final sid = int.tryParse(id);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));

      final sprint = await SprintService.getSprintById(sid);
      if (sprint == null) return Response.notFound(jsonEncode({'error': 'Sprint not found'}));

      return Response.ok(jsonEncode(sprint), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _createSprint(Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      await SprintService.createSprint(payload);
      return Response(201, body: jsonEncode({'success': true, 'message': 'Sprint created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _updateSprint(Request request, String id) async {
    try {
      final sid = int.tryParse(id);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final payload = jsonDecode(await request.readAsString());
      await SprintService.updateSprint(sid, payload);
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

      final res = await SprintService.deleteSprint(sid);
      if (!res['success']) return Response(409, body: jsonEncode({'error': res['message']}));

      return Response.ok(jsonEncode({'success': true, 'message': 'Sprint deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}
