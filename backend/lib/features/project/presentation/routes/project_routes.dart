import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/project_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class ProjectRoutes {
  late final Router router;

  ProjectRoutes() {
    router = Router()
      ..get('/', _getAllProjects)
      ..get('/available-employees', _getAvailableEmployees)
      ..get('/check-deadlines', _manualCheckDeadlines)
      ..get('/<id>', _getProjectById)
      ..post('/', _createProject)
      ..put('/<id>', _updateProject)
      ..delete('/<id>', _deleteProject)
      ..get('/<id>/members', _getProjectMembers)
      ..post('/<id>/members', _addProjectMember)
      ..delete('/<id>/members/<employeeId>', _removeProjectMember);
  }

  Future<Response> _getAllProjects(Request request) async {
    try {
      final projects = await ProjectService.getAllProjects();
      return Response.ok(jsonEncode(projects), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('❌ ERROR in _getAllProjects: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load projects: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  Future<Response> _manualCheckDeadlines(Request request) async {
    try {
      await ProjectService.checkDeadlines();
      return Response.ok(jsonEncode({'success': true, 'message': 'Deadlines checked'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getProjectById(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid format'}));
      
      final project = await ProjectService.getProjectById(id);
      if (project == null) return Response.notFound(jsonEncode({'error': 'Project not found'}));
      
      return Response.ok(jsonEncode(project), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to load project: $e'}));
    }
  }

  Future<Response> _createProject(Request request) async {
    try {
      if (!request.isAdmin) return Response.forbidden(jsonEncode({'error': 'Admin only'}));
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final newId = await ProjectService.createProject(data);
      return Response(201, body: jsonEncode({'success': true, 'id': newId, 'message': 'Project created'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to create project: $e'}));
    }
  }

  Future<Response> _updateProject(Request request, String idString) async {
    try {
      if (!request.isAdmin) return Response.forbidden(jsonEncode({'error': 'Admin only'}));
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final body = await request.readAsString();
      final data = jsonDecode(body);
      await ProjectService.updateProject(id, data);
      return Response.ok(jsonEncode({'success': true, 'message': 'Project updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to update project: $e'}));
    }
  }

  Future<Response> _deleteProject(Request request, String idString) async {
    try {
      if (!request.isAdmin) return Response.forbidden(jsonEncode({'error': 'Admin only'}));
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));

      final res = await ProjectService.deleteProject(id);
      if (!res['success']) return Response(409, body: jsonEncode({'error': res['message']}));

      return Response.ok(jsonEncode({'success': true, 'message': 'Project deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to delete project: $e'}));
    }
  }

  Future<Response> _getAvailableEmployees(Request request) async {
    try {
      final employees = await ProjectService.getAvailableEmployees();
      return Response.ok(jsonEncode(employees), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to load employees: $e'}));
    }
  }

  Future<Response> _getProjectMembers(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final members = await ProjectService.getProjectMembers(id);
      return Response.ok(jsonEncode(members), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to load members: $e'}));
    }
  }

  Future<Response> _addProjectMember(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final body = await request.readAsString();
      final data = jsonDecode(body);
      await ProjectService.addProjectMember(id, data['employeeId'], role: data['role'] ?? 'Membre');
      return Response.ok(jsonEncode({'success': true, 'message': 'Member added'}));
    } catch (e) {
      if (e.toString().contains('Duplicate entry')) {
        return Response.badRequest(body: jsonEncode({'error': 'Employee already in team'}));
      }
      return Response.internalServerError(body: jsonEncode({'error': 'Failed: $e'}));
    }
  }

  Future<Response> _removeProjectMember(Request request, String idString, String employeeId) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      await ProjectService.removeProjectMember(id, employeeId);
      return Response.ok(jsonEncode({'success': true, 'message': 'Member removed'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed: $e'}));
    }
  }
}
