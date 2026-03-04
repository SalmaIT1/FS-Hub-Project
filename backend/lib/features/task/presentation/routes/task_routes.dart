import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/task_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class TaskRoutes {
  late final Router router;

  TaskRoutes() {
    router = Router()
      ..get('/', _getAllTasks)
      ..get('/my-tasks', _getMyTasks)
      ..get('/sprint/<sprintId>', _getTasksBySprint)
      ..get('/<id>', _getTaskById)
      ..get('/sprint/<sprintId>/burndown', _getBurndownData)
      ..post('/', _createTask)
      ..put('/<id>', _updateTask)
      ..delete('/<id>', _deleteTask);
  }

  Future<Response> _getAllTasks(Request request) async {
    try {
      final tasks = await TaskService.getAllTasks();
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getMyTasks(Request request) async {
    try {
      final userId = request.authUserId;
      final tasks = await TaskService.getMyTasks(userId);
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getTasksBySprint(Request request, String sprintId) async {
    try {
      final sid = int.tryParse(sprintId);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final tasks = await TaskService.getTasksBySprint(sid);
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getTaskById(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid format'}));
      
      final task = await TaskService.getTaskById(id);
      if (task == null) return Response.notFound(jsonEncode({'error': 'Task not found'}));
      return Response.ok(jsonEncode(task), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _createTask(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      if (data['sprintId'] == null || data['titre'] == null) {
        return Response(400, body: jsonEncode({'error': 'Sprint ID and Title are required'}));
      }
      await TaskService.createTask(data);
      return Response(201, body: jsonEncode({'success': true, 'message': 'Task created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _updateTask(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final data = jsonDecode(await request.readAsString());
      await TaskService.updateTask(id, data);
      return Response.ok(jsonEncode({'success': true, 'message': 'Task updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _deleteTask(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      await TaskService.deleteTask(id);
      return Response.ok(jsonEncode({'success': true, 'message': 'Task deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getBurndownData(Request request, String sprintId) async {
    try {
      final sid = int.tryParse(sprintId);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final data = await TaskService.getBurndownData(sid);
      return Response.ok(jsonEncode(data), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}
