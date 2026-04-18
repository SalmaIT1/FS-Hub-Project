import 'dart:convert';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/project_service.dart';
import '../../data/repositories/project_repository.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';

class ProjectRoutes {
  late final Router router;
  final _repo = ProjectRepository();

  ProjectRoutes() {
    router = Router()
      ..get('/', Pipeline().addMiddleware(requirePermission('view_projects')).addHandler(_getAllProjects))
      ..get('/available-employees', Pipeline().addMiddleware(requirePermission('view_employees')).addHandler(_getAvailableEmployees))
      ..get('/check-deadlines', Pipeline().addMiddleware(requirePermission('manage_projects')).addHandler(_manualCheckDeadlines))
      ..get('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_projects')).addHandler((req) => _getProjectById(req, id))(request))
      ..post('/', Pipeline().addMiddleware(requirePermission('manage_projects')).addHandler(_createProject))
      ..put('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_projects')).addHandler((req) => _updateProject(req, id))(request))
      ..delete('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_projects')).addHandler((req) => _deleteProject(req, id))(request))
      ..get('/<id>/members', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_projects')).addHandler((req) => _getProjectMembers(req, id))(request))
      ..post('/<id>/members', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_projects')).addHandler((req) => _addProjectMember(req, id))(request))
      ..delete('/<id>/members/<employeeId>', (Request request, String id, String employeeId) => Pipeline().addMiddleware(requirePermission('manage_projects')).addHandler((req) => _removeProjectMember(req, id, employeeId))(request))
      // Contract upload — Admin only
      ..post('/<id>/contract', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_projects')).addHandler((req) => _uploadContract(req, id))(request))
      ..get('/<id>/contract/status', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_projects')).addHandler((req) => _getContractStatus(req, id))(request));
  }

  Future<Response> _getAllProjects(Request request) async {
    try {
      final projects = await ProjectService.getAllProjects(
        callerRole: request.authUserRole,
        callerId: request.authUserId,
      );
      return Response.ok(jsonEncode(projects), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _manualCheckDeadlines(Request request) async {
    try {
      await ProjectService.checkDeadlines();
      return Response.ok(jsonEncode({'success': true, 'message': 'Deadlines checked'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getProjectById(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid format'}));
      
      final project = await ProjectService.getProjectById(
        id, 
        callerRole: request.authUserRole, 
        callerId: request.authUserId
      );
      if (project == null) return Response.notFound(jsonEncode({'error': 'Project not found or access denied'}));
      
      return Response.ok(jsonEncode(project), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _createProject(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final newId = await ProjectService.createProject(data, callerId: request.authUserId);
      return Response(201, body: jsonEncode({'success': true, 'id': newId, 'message': 'Project created'}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'error': e.toString().replaceFirst('Exception: ', '')}));
    }
  }

  Future<Response> _updateProject(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final body = await request.readAsString();
      final data = jsonDecode(body);
      await ProjectService.updateProject(id, data, callerId: request.authUserId);
      return Response.ok(jsonEncode({'success': true, 'message': 'Project updated'}));
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.startsWith('CONTRACT_REQUIRED')) {
        return Response(
          422,
          body: jsonEncode({'success': false, 'error': 'contract_required', 'message': 'Un contrat d\'engagement signé doit être uploadé avant de démarrer ce projet.'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
      return Response.badRequest(body: jsonEncode({'error': msg}));
    }
  }

  Future<Response> _deleteProject(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));

      final res = await ProjectService.deleteProject(id, callerId: request.authUserId);
      if (!res['success']) return Response(409, body: jsonEncode({'error': res['message']}));

      return Response.ok(jsonEncode({'success': true, 'message': 'Project deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getAvailableEmployees(Request request) async {
    try {
      final employees = await ProjectService.getAvailableEmployees();
      return Response.ok(jsonEncode(employees), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getProjectMembers(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final members = await ProjectService.getProjectMembers(id);
      return Response.ok(jsonEncode(members), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
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
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _removeProjectMember(Request request, String idString, String employeeId) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      await ProjectService.removeProjectMember(id, employeeId);
      return Response.ok(jsonEncode({'success': true, 'message': 'Member removed'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  // ── POST /<id>/contract ────────────────────────────────────────────────────
  Future<Response> _uploadContract(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'success': false, 'error': 'Invalid project ID'}));

      final contentType = request.headers['content-type'] ?? '';
      if (!contentType.contains('multipart/form-data')) {
        return Response.badRequest(body: jsonEncode({'success': false, 'error': 'Expected multipart/form-data'}));
      }

      final boundary = contentType.split('boundary=').last.trim();
      final transformer = MimeMultipartTransformer(boundary);
      final bodyStream = request.read();
      final parts = await transformer.bind(bodyStream).toList();

      if (parts.isEmpty) {
        return Response.badRequest(body: jsonEncode({'success': false, 'error': 'No file found in request'}));
      }

      final part = parts.first;
      final disposition = part.headers['content-disposition'] ?? '';
      final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
      final filename = filenameMatch?.group(1) ?? 'contract.pdf';

      final bytes = await part.fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));
      if (bytes.isEmpty) {
        return Response.badRequest(body: jsonEncode({'success': false, 'error': 'Empty file'}));
      }

      final result = await _repo.uploadContract(id, bytes, filename);
      return Response.ok(
        jsonEncode({'success': true, 'message': 'Contract uploaded successfully', 'data': result}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // ── GET /<id>/contract/status ──────────────────────────────────────────────
  Future<Response> _getContractStatus(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'success': false, 'error': 'Invalid project ID'}));

      final hasContract = await _repo.hasContract(id);
      return Response.ok(
        jsonEncode({'success': true, 'hasContract': hasContract}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }
}
