import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/task_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';

class TaskRoutes {
  late final Router router;

  TaskRoutes() {
    final secured = Pipeline().addMiddleware(requireAuth());
    router = Router()
      ..get('/', secured.addMiddleware(requirePermission('view_tasks')).addHandler(_getAllTasks))
      ..get('/my-tasks', secured.addMiddleware(requirePermission('execute_tasks')).addHandler(_getMyTasks))
      ..get('/sprint/<sprintId>', (Request request, String sprintId) => secured.addMiddleware(requirePermission('view_tasks')).addHandler((req) => _getTasksBySprint(req, sprintId))(request))
      ..get('/<id>', (Request request, String id) => secured.addMiddleware(requirePermission('view_tasks')).addHandler((req) => _getTaskById(req, id))(request))
      ..get('/sprint/<sprintId>/burndown', (Request request, String sprintId) => secured.addMiddleware(requirePermission('view_tasks')).addHandler((req) => _getBurndownData(req, sprintId))(request))
      ..post('/', secured.addMiddleware(requirePermission('manage_tasks')).addHandler(_createTask))
      ..post('/bulk-assign', secured.addMiddleware(requirePermission('manage_tasks')).addHandler(_bulkAssignTasks))
      ..put('/<id>', (Request request, String id) => secured.addMiddleware(requireRoleOrPermission([], ['manage_tasks', 'update_task_progress'])).addHandler((req) => _updateTask(req, id))(request))
      ..delete('/<id>', (Request request, String id) => secured.addMiddleware(requirePermission('manage_tasks')).addHandler((req) => _deleteTask(req, id))(request));
  }

  Future<Response> _getAllTasks(Request request) async {
    try {
      final tasks = await TaskService.getAllTasks();
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getMyTasks(Request request) async {
    try {
      final userId = request.authUserId;
      final tasks = await TaskService.getMyTasks(userId);
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getTasksBySprint(Request request, String sprintId) async {
    try {
      final sid = int.tryParse(sprintId);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final tasks = await TaskService.getTasksBySprint(
        sid,
        callerRole: request.authUserRole,
        callerId: request.authUserId,
      );
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getTaskById(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid format'}));
      
      final task = await TaskService.getTaskById(
        id, 
        callerRole: request.authUserRole, 
        callerId: request.authUserId
      );
      if (task == null) return Response.notFound(jsonEncode({'error': 'Task not found or access denied'}));
      return Response.ok(jsonEncode(task), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _createTask(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      if (data['sprintId'] == null || data['titre'] == null) {
        return Response(400, body: jsonEncode({'error': 'Sprint ID and Title are required'}));
      }
      await TaskService.createTask(data, callerId: request.authUserId);
      return Response(201, body: jsonEncode({'success': true, 'message': 'Task created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _bulkAssignTasks(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final taskIds = List<int>.from(data['taskIds'] ?? []);
      final employeeId = data['employeeId'];
      
      if (employeeId == null) return Response.badRequest(body: jsonEncode({'error': 'employeeId is required'}));
      
      final res = await TaskService.bulkAssignTasks(taskIds, employeeId, callerId: request.authUserId);
      return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _updateTask(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final data = jsonDecode(await request.readAsString());
      await TaskService.updateTask(id, data, request.authUserId, request.authUserPermissions, request.isAdmin);
      return Response.ok(jsonEncode({'success': true, 'message': 'Task updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _deleteTask(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      await TaskService.deleteTask(id, callerId: request.authUserId);
      return Response.ok(jsonEncode({'success': true, 'message': 'Task deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getBurndownData(Request request, String sprintId) async {
    try {
      final sid = int.tryParse(sprintId);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final data = await TaskService.getBurndownData(
        sid,
        callerRole: request.authUserRole,
        callerId: request.authUserId,
      );
      return Response.ok(jsonEncode(data), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }
}
