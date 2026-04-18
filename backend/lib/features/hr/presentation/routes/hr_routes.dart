import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/hr_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';

class HrRoutes {
  late final Router router;

  HrRoutes() {
    router = Router()
      // Attendance
      ..get('/attendance', Pipeline().addMiddleware(requirePermission('manage_attendance')).addHandler(_getAllAttendance))
      // FIX: Employees use 'log_own_attendance' to check in/out themselves. Admins/RH use 'manage_attendance' to log for others.
      ..get('/attendance/<employeeId>', (Request request, String employeeId) => Pipeline().addMiddleware(requireRoleOrPermission([], ['view_employees', 'log_own_attendance'])).addHandler((req) => _getAttendance(req, employeeId))(request))
      ..post('/attendance/self', Pipeline().addMiddleware(requirePermission('log_own_attendance')).addHandler(_logSelfAttendance))
      ..post('/attendance', Pipeline().addMiddleware(requirePermission('manage_attendance')).addHandler(_logAttendance))
      ..post('/attendance/bulk', Pipeline().addMiddleware(requirePermission('manage_attendance')).addHandler(_bulkCorrectAttendance))
      
      // Leaves
      // FIX: 'submit_leave' is for employees creating their own requests; 'manage_leaves' is for Admin/RH approvals.
      ..get('/leaves', Pipeline().addMiddleware(requireRoleOrPermission([], ['view_employees', 'submit_leave'])).addHandler(_getLeaveRequests))
      ..post('/leaves', Pipeline().addMiddleware(requirePermission('submit_leave')).addHandler(_submitLeaveRequest))
      ..put('/leaves/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_leaves')).addHandler((req) => _updateLeaveStatus(req, id))(request))
      
      // Remote Work
      // FIX: Same pattern as leaves — employees submit via 'submit_remote_work'
      ..get('/remote-work', Pipeline().addMiddleware(requireRoleOrPermission([], ['view_employees', 'submit_remote_work'])).addHandler(_getRemoteWorkRequests))
      ..post('/remote-work', Pipeline().addMiddleware(requirePermission('submit_remote_work')).addHandler(_submitRemoteWorkRequest))
      ..put('/remote-work/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_remote_work')).addHandler((req) => _updateRemoteWorkStatus(req, id))(request))
      
      // Salaries
      // FIX: Added 'view_own_salary' permission path for employees to see their own salary without having view_employees
      ..get('/salaries', _getSalaries)  // internal role-scoping in HrService handles what each role can see
      ..post('/salaries', Pipeline().addMiddleware(requirePermission('manage_salaries')).addHandler(_createSalary))
      ..post('/salaries/bulk-generate', Pipeline().addMiddleware(requirePermission('manage_salaries')).addHandler(_bulkGenerateSalaries))  // FIX: Missing route added
      ..put('/salaries/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_salaries')).addHandler((req) => _updateSalaryStatus(req, id))(request))
      
      // Bonuses
      ..get('/bonuses', _getBonuses)
      ..get('/bonuses/<employeeId>', (Request req, String id) => _getBonuses(req, targetEmployeeId: id))
      ..post('/bonuses', Pipeline().addMiddleware(requirePermission('manage_bonuses')).addHandler(_grantBonus))
      ..post('/bonuses/bulk', Pipeline().addMiddleware(requirePermission('manage_bonuses')).addHandler(_bulkGrantBonuses))
      
      // Payslip Export (HTML Print)
      // Allow ANY authenticated user or at least allow it if they are viewing salaries
      ..get('/salaries/<id>/payslip', _getPayslipHtml);
  }

  // --- Attendance ---

  Future<Response> _getAttendance(Request request, String employeeId) async {
    final callerRole = request.authUserRole;
    final callerId = request.authUserId;
    if (callerRole == 'Employé' && callerId != employeeId && !request.isAdmin) {
      return Response.forbidden(jsonEncode({'success': false, 'message': 'Cannot view attendance records of other personnel.'}));
    }
    
    final params = request.url.queryParameters;
    final res = await HrService.getAttendance(employeeId, startDate: params['startDate'], endDate: params['endDate']);
    if (!res['success']) return Response.internalServerError(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _getAllAttendance(Request request) async {
    final params = request.url.queryParameters;
    final date = params['date'];
    if (date == null) return Response.badRequest(body: jsonEncode({'success': false, 'message': 'date parameter is required'}));
    
    final res = await HrService.getAllAttendance(date);
    if (!res['success']) return Response.internalServerError(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _logAttendance(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final res = await HrService.logAttendance(data, callerId: request.authUserId);
    if (!res['success']) return Response.badRequest(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _logSelfAttendance(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final userId = request.authUserId;
    
    // Safety: ignore any employeeId in the body and use authUserId
    data['employee_id'] = userId;
    
    final res = await HrService.logAttendance(data);
    if (!res['success']) return Response.badRequest(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _bulkCorrectAttendance(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final ids = List<String>.from(data['employeeIds'] ?? []);
    final date = data['date'];
    final status = data['status'];
    
    if (date == null || status == null) return Response.badRequest(body: jsonEncode({'success': false, 'message': 'date and status are required'}));
    
    final res = await HrService.bulkCorrectAttendance(ids, date, status, callerId: request.authUserId);
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  // --- Leaves ---

  Future<Response> _getLeaveRequests(Request request) async {
    final role = request.authUserRole;
    final userId = request.authUserId;
    if (userId == null) return Response.forbidden(jsonEncode({'success': false, 'message': 'Unauthorized'}));
    
    final res = await HrService.getLeaveRequests(role, userId);
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _submitLeaveRequest(Request request) async {
    final userId = request.authUserId;
    if (userId == null) return Response.forbidden(jsonEncode({'success': false, 'message': 'Unauthorized'}));
    
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final res = await HrService.submitLeaveRequest(userId, data);
    if (!res['success']) return Response.badRequest(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _updateLeaveStatus(Request request, String id) async {
    final userId = request.authUserId;
    if (userId == null) return Response.forbidden(jsonEncode({'success': false, 'message': 'Unauthorized'}));

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    final status = data['status'];
    if (status == null) return Response.badRequest(body: jsonEncode({'success': false, 'message': 'Missing status'}));
    
    final res = await HrService.updateLeaveStatus(int.parse(id), status, userId);
    if (!res['success']) return Response.internalServerError(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  // --- Remote Work ---

  Future<Response> _getRemoteWorkRequests(Request request) async {
    final role = request.authUserRole;
    final userId = request.authUserId;
    if (userId == null) return Response.forbidden(jsonEncode({'success': false, 'message': 'Unauthorized'}));
    
    final res = await HrService.getRemoteWorkRequests(role, userId);
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _submitRemoteWorkRequest(Request request) async {
    final userId = request.authUserId;
    if (userId == null) return Response.forbidden(jsonEncode({'success': false, 'message': 'Unauthorized'}));
    
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final res = await HrService.submitRemoteWorkRequest(userId, data);
    if (!res['success']) return Response.badRequest(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _updateRemoteWorkStatus(Request request, String id) async {
    final userId = request.authUserId;
    if (userId == null) return Response.forbidden(jsonEncode({'success': false, 'message': 'Unauthorized'}));

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    final status = data['status'];
    if (status == null) return Response.badRequest(body: jsonEncode({'success': false, 'message': 'Missing status'}));
    
    final res = await HrService.updateRemoteWorkStatus(int.parse(id), status, userId);
    if (!res['success']) return Response.internalServerError(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  // --- Salaries ---

  Future<Response> _getSalaries(Request request) async {
    final role = request.authUserRole;
    final userId = request.authUserId;
    if (userId == null) return Response.forbidden(jsonEncode({'success': false, 'message': 'Unauthorized'}));
    
    final params = request.url.queryParameters;
    final targetEmployeeId = params['employeeId'];

    final res = await HrService.getSalaries(role, userId, targetEmployeeId: targetEmployeeId);
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _createSalary(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final res = await HrService.createSalary(data, callerId: request.authUserId);
    if (!res['success']) return Response.badRequest(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _updateSalaryStatus(Request request, String id) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    final status = data['status'];
    if (status == null) return Response.badRequest(body: jsonEncode({'success': false, 'message': 'Missing status'}));
    
    final res = await HrService.updateSalaryStatus(int.parse(id), status, callerId: request.authUserId);
    if (!res['success']) return Response.internalServerError(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _getPayslipHtml(Request request, String id) async {
    final callerId = request.authUserId;
    final callerRole = request.authUserRole;
    final isAdminOrRH = callerRole == 'Admin' || callerRole == 'RH' || callerRole == 'Comptable';
    
    // Check ownership
    if (!isAdminOrRH) {
      final salaryOwnerId = await HrService.getSalaryEmployeeId(int.parse(id));
      if (salaryOwnerId != callerId) {
        return Response.forbidden(jsonEncode({'success': false, 'message': 'You are not authorized to view this payslip.'}));
      }
    }

    final html = await HrService.generatePayslipHtmlForSalary(int.parse(id));
    if (html == null) {
      return Response.notFound('Fiche de paie introuvable.');
    }
    // Set headers so the browser renders it immediately and can use window.print()
    return Response.ok(
      '$html<script>window.onload = function() { window.print(); }</script>', 
      headers: {'Content-Type': 'text/html; charset=utf-8'}
    );
  }

  // --- Bulk Salary Generation ---

  Future<Response> _bulkGenerateSalaries(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final month = data['month']?.toString();
    if (month == null) return Response.badRequest(body: jsonEncode({'success': false, 'message': 'month is required (format: YYYY-MM)'}));
    final res = await HrService.bulkGenerateSalaries(month, callerId: request.authUserId);
    if (!res['success']) return Response.internalServerError(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  // --- Bonuses ---

  Future<Response> _getBonuses(Request request, {String? targetEmployeeId}) async {
    final callerRole = request.authUserRole;
    final callerId = request.authUserId ?? '';
    
    // If targetEmployeeId is not in path, check query params
    final employeeId = targetEmployeeId ?? request.url.queryParameters['employeeId'];

    final res = await HrService.getBonuses(callerRole, callerId, targetEmployeeId: employeeId);
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _grantBonus(Request request) async {
    final userId = request.authUserId;
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    if (userId != null && data['granted_by'] == null) {
        data['granted_by'] = userId;
    }
    
    final res = await HrService.grantBonus(data);
    if (!res['success']) return Response.badRequest(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }

  Future<Response> _bulkGrantBonuses(Request request) async {
    final userId = request.authUserId;
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    final employeeIds = List<String>.from(data['employeeIds'] ?? []);
    final bonusData = Map<String, dynamic>.from(data['bonus'] ?? {});

    if (userId != null && bonusData['granted_by'] == null) {
      bonusData['granted_by'] = userId;
    }

    final res = await HrService.bulkGrantBonuses(employeeIds, bonusData);
    if (!res['success']) return Response.badRequest(body: jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json; charset=utf-8'});
  }
}
