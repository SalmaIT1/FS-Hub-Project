import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/employee_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';

class EmployeeRoutes {
  late final Router router;

  EmployeeRoutes() {
    router = Router()
      ..get('/', Pipeline().addMiddleware(requirePermission('view_employees')).addHandler(_getAllEmployees))
      ..get('/<id>', (Request request, String id) {
        if (id == request.authUserId) {
          return _getEmployeeById(request, id);
        }
        return Pipeline().addMiddleware(requirePermission('view_employees')).addHandler((req) => _getEmployeeById(req, id))(request);
      })
      ..post('/', Pipeline().addMiddleware(requirePermission('manage_employees')).addHandler(_createEmployee))
      ..put('/<id>', (Request request, String id) {
        if (id == request.authUserId) {
          return _updateEmployee(request, id);
        }
        return Pipeline().addMiddleware(requirePermission('manage_employees')).addHandler((req) => _updateEmployee(req, id))(request);
      })
      ..delete('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_employees')).addHandler((req) => _deleteEmployee(req, id))(request));
  }

  Future<Response> _getAllEmployees(Request request) async {
    final params = request.url.queryParameters;
    final page = int.tryParse(params['page'] ?? '1') ?? 1;
    final limit = (int.tryParse(params['limit'] ?? '50') ?? 50).clamp(1, 200);

    final res = await EmployeeService.getAllEmployees(
      page: page, 
      limit: limit, 
      callerRole: request.authUserRole, 
      callerId: request.authUserId,
    );
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _getEmployeeById(Request request, String id) async {
    final res = await EmployeeService.getEmployeeById(
      id, 
      callerRole: request.authUserRole, 
      callerId: request.authUserId,
    );
    if (!res['success']) return Response.notFound(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _createEmployee(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final res = await EmployeeService.createEmployee(data, callerId: request.authUserId);
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _updateEmployee(Request request, String id) async {
    final callerRole = request.authUserRole;
    final callerId = request.authUserId;

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final res = await EmployeeService.updateEmployee(id, data, callerRole: callerRole, callerId: callerId);
    if (!res['success']) return Response(403, body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});

    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _deleteEmployee(Request request, String id) async {
    final callerRole = request.authUserRole;
    final res = await EmployeeService.deactivateEmployee(id, callerRole: callerRole, callerId: request.authUserId);
    if (!res['success']) return Response(403, body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});

    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }
}
