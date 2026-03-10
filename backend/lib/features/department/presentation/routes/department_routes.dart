import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/department_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';

class DepartmentRoutes {
  late final Router router;

  DepartmentRoutes() {
    router = Router()
      ..get('/', Pipeline().addMiddleware(requirePermission('view_employees')).addHandler(_getAllDepartments))
      ..get('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_employees')).addHandler((req) => _getDepartmentById(req, id))(request))
      ..post('/', Pipeline().addMiddleware(requirePermission('manage_system')).addHandler(_createDepartment))
      ..put('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_system')).addHandler((req) => _updateDepartment(req, id))(request))
      ..delete('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_system')).addHandler((req) => _deleteDepartment(req, id))(request));
  }

  Future<Response> _getAllDepartments(Request request) async {
    try {
      final depts = await DepartmentService.getAllDepartments();
      return Response.ok(jsonEncode({'success': true, 'data': depts}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error: $e'}));
    }
  }

  Future<Response> _getDepartmentById(Request request, String id) async {
    try {
      final dept = await DepartmentService.getDepartmentById(id);
      if (dept == null) return Response.notFound(jsonEncode({'success': false, 'message': 'Department not found'}));
      return Response.ok(jsonEncode({'success': true, 'data': dept}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error: $e'}));
    }
  }

  Future<Response> _createDepartment(Request request) async {
    try {
      if (!request.isRH) return Response.forbidden(jsonEncode({'success': false, 'message': 'Admin or RH only'}));
      final body = await request.readAsString();
      final data = jsonDecode(body);
      if (data['nom'] == null || data['nom'].toString().isEmpty) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'Department name is required'}));
      }
      await DepartmentService.createDepartment(data);
      return Response.ok(jsonEncode({'success': true, 'message': 'Department created successfully'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error: $e'}));
    }
  }

  Future<Response> _updateDepartment(Request request, String id) async {
    try {
      if (!request.isRH) return Response.forbidden(jsonEncode({'success': false, 'message': 'Admin or RH only'}));
      final body = await request.readAsString();
      final data = jsonDecode(body);
      await DepartmentService.updateDepartment(id, data);
      return Response.ok(jsonEncode({'success': true, 'message': 'Department updated successfully'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error: $e'}));
    }
  }

  Future<Response> _deleteDepartment(Request request, String id) async {
    try {
      if (!request.isAdmin) return Response.forbidden(jsonEncode({'success': false, 'message': 'Admin only'}));
      final res = await DepartmentService.deleteDepartment(id);
      if (!res['success']) return Response(400, body: jsonEncode(res));
      return Response.ok(jsonEncode({'success': true, 'message': 'Department deleted successfully'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}));
    }
  }
}
