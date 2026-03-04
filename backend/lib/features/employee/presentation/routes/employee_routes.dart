import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/employee_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class EmployeeRoutes {
  late final Router router;

  EmployeeRoutes() {
    router = Router()
      ..get('/', _getAllEmployees)
      ..get('/<id>', _getEmployeeById)
      ..post('/', _createEmployee)
      ..put('/<id>', _updateEmployee)
      ..delete('/<id>', _deleteEmployee);
  }

  Future<Response> _getAllEmployees(Request request) async {
    final params = request.url.queryParameters;
    final page = int.tryParse(params['page'] ?? '1') ?? 1;
    final limit = (int.tryParse(params['limit'] ?? '50') ?? 50).clamp(1, 200);

    final res = await EmployeeService.getAllEmployees(page: page, limit: limit);
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getEmployeeById(Request request, String id) async {
    final res = await EmployeeService.getEmployeeById(id);
    if (!res['success']) return Response.notFound(jsonEncode(res), headers: {'Content-Type': 'application/json'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _createEmployee(Request request) async {
    final callerRole = request.authUserRole;
    if (callerRole != 'Admin' && callerRole != 'RH') {
      return Response(403, body: jsonEncode({'success': false, 'message': 'Admin or RH role required'}), headers: {'Content-Type': 'application/json'});
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final res = await EmployeeService.createEmployee(data);
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _updateEmployee(Request request, String id) async {
    final callerRole = request.authUserRole;
    final callerId = request.authUserId;

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final res = await EmployeeService.updateEmployee(id, data, callerRole: callerRole, callerId: callerId);
    if (!res['success']) return Response(403, body: jsonEncode(res), headers: {'Content-Type': 'application/json'});

    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _deleteEmployee(Request request, String id) async {
    final callerRole = request.authUserRole;
    final res = await EmployeeService.deactivateEmployee(id, callerRole: callerRole);
    if (!res['success']) return Response(403, body: jsonEncode(res), headers: {'Content-Type': 'application/json'});

    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }
}
