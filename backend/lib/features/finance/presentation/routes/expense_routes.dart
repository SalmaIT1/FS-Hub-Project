import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/expense_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';
import '../../data/models/expense_model.dart';

class ExpenseRoutes {
  final ExpenseService _expenseService = ExpenseService();
  final Router _router = Router();

  ExpenseRoutes() {
    _setupRoutes();
  }

  void _setupRoutes() {
    // Project expenses routes
    _router.get('/project-expenses', Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler(_getAllProjectExpenses));
    _router.get('/project-expenses/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler((req) => _getProjectExpenseById(req, id))(request));
    _router.post('/project-expenses', Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler(_createProjectExpense));
    _router.put('/project-expenses/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler((req) => _updateProjectExpense(req, id))(request));
    _router.delete('/project-expenses/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler((req) => _deleteProjectExpense(req, id))(request));
    _router.get('/project-expenses/summary', Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler(_getProjectExpenseSummary));

    // Company expenses routes
    _router.get('/company-expenses', Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler(_getAllCompanyExpenses));
    _router.get('/company-expenses/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler((req) => _getCompanyExpenseById(req, id))(request));
    _router.post('/company-expenses', Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler(_createCompanyExpense));
    _router.put('/company-expenses/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler((req) => _updateCompanyExpense(req, id))(request));
    _router.delete('/company-expenses/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler((req) => _deleteCompanyExpense(req, id))(request));
    _router.get('/company-expenses/summary', Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler(_getCompanyExpenseSummary));

    // Approval routes
    _router.post('/project-expenses/<id>/approve', (Request request, String id) => Pipeline().addMiddleware(requireRoleOrPermission(['Admin', 'Manager', 'RH', 'Comptable'], [])).addHandler((req) => _approveExpense(req, id, 'project'))(request));
    _router.post('/project-expenses/<id>/reject', (Request request, String id) => Pipeline().addMiddleware(requireRoleOrPermission(['Admin', 'Manager', 'RH', 'Comptable'], [])).addHandler((req) => _rejectExpense(req, id, 'project'))(request));
    _router.post('/company-expenses/<id>/approve', (Request request, String id) => Pipeline().addMiddleware(requireRoleOrPermission(['Admin', 'Manager', 'RH', 'Comptable'], [])).addHandler((req) => _approveExpense(req, id, 'company'))(request));
    _router.post('/company-expenses/<id>/reject', (Request request, String id) => Pipeline().addMiddleware(requireRoleOrPermission(['Admin', 'Manager', 'RH', 'Comptable'], [])).addHandler((req) => _rejectExpense(req, id, 'company'))(request));

    // Categories routes
    _router.get('/expense-categories', Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler(_getExpenseCategories));
    _router.post('/expense-categories', Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler(_createExpenseCategory));
    _router.get('/company-expense-categories', Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler(_getCompanyExpenseCategories));
    _router.post('/company-expense-categories', Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler(_createCompanyExpenseCategory));
  }

  // Project expenses handlers
  Future<Response> _getAllProjectExpenses(Request request) async {
    try {
      final projectIdStr = request.url.queryParameters['project_id'];
      final projectId = projectIdStr != null ? int.tryParse(projectIdStr) : null;
      
      final expenses = await _expenseService.getProjectExpensesWithDetails(projectId: projectId);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': expenses,
          'message': 'Project expenses retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve project expenses: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getProjectExpenseById(Request request, String id) async {
    try {
      final expenseId = int.parse(id);
      final expense = await _expenseService.getProjectExpenseById(expenseId);
      
      if (expense == null) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'Project expense not found',
          }),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': expense?.toJson() ?? {},
          'message': 'Project expense retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve project expense: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _createProjectExpense(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      // Add created_by from authenticated user
      final user = request.context['user'] as Map<String, dynamic>?;
      if (user != null) {
        json['created_by'] = user['username'];
      }
      
      final result = await _expenseService.createProjectExpenseFromJson(json);
      
      return Response(
        result['success'] ? 201 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create project expense: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _updateProjectExpense(Request request, String id) async {
    try {
      final expenseId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _expenseService.updateProjectExpenseFromJson(expenseId, json);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to update project expense: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _deleteProjectExpense(Request request, String id) async {
    try {
      final expenseId = int.parse(id);
      final result = await _expenseService.deleteProjectExpenseWithResponse(expenseId);
      
      return Response(
        result['success'] ? 200 : 404,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to delete project expense: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getProjectExpenseSummary(Request request) async {
    try {
      final projectIdStr = request.url.queryParameters['project_id'];
      final projectId = projectIdStr != null ? int.tryParse(projectIdStr) : null;
      
      final summary = await _expenseService.getProjectExpenseSummary(projectId: projectId);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': summary,
          'message': 'Project expense summary retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve project expense summary: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  // Company expenses handlers
  Future<Response> _getAllCompanyExpenses(Request request) async {
    try {
      final expenses = await _expenseService.getCompanyExpensesWithDetails();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': expenses,
          'message': 'Company expenses retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve company expenses: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getCompanyExpenseById(Request request, String id) async {
    try {
      final expenseId = int.parse(id);
      final expense = await _expenseService.getCompanyExpenseById(expenseId);
      
      if (expense == null) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'Company expense not found',
          }),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': expense?.toJson() ?? {},
          'message': 'Company expense retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve company expense: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _createCompanyExpense(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      // Add created_by from authenticated user
      final user = request.context['user'] as Map<String, dynamic>?;
      if (user != null) {
        json['created_by'] = user['username'];
      }
      
      final result = await _expenseService.createCompanyExpenseFromJson(json);
      
      return Response(
        result['success'] ? 201 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create company expense: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _updateCompanyExpense(Request request, String id) async {
    try {
      final expenseId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _expenseService.updateCompanyExpenseFromJson(expenseId, json);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to update company expense: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _deleteCompanyExpense(Request request, String id) async {
    try {
      final expenseId = int.parse(id);
      final result = await _expenseService.deleteCompanyExpenseWithResponse(expenseId);
      
      return Response(
        result['success'] ? 200 : 404,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to delete company expense: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getCompanyExpenseSummary(Request request) async {
    try {
      final summary = await _expenseService.getCompanyExpenseSummary();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': summary,
          'message': 'Company expense summary retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve company expense summary: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  // Categories handlers
  Future<Response> _getExpenseCategories(Request request) async {
    try {
      final categories = await _expenseService.getExpenseCategories();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': categories.map((c) => c?.toJson() ?? {}).toList(),
          'message': 'Expense categories retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve expense categories: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _createExpenseCategory(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final category = await _expenseService.createExpenseCategory(
        ExpenseCategoryModel(
          nom: json['nom'],
          description: json['description'],
        ),
      );
      
      return Response(
        201,
        body: jsonEncode({
          'success': true,
          'data': category?.toJson() ?? {},
          'message': 'Expense category created successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create expense category: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getCompanyExpenseCategories(Request request) async {
    try {
      final categories = await _expenseService.getCompanyExpenseCategories();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': categories.map((c) => c?.toJson() ?? {}).toList(),
          'message': 'Company expense categories retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve company expense categories: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _createCompanyExpenseCategory(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final category = await _expenseService.createCompanyExpenseCategory(
        ExpenseCategoryModel(
          nom: json['nom'],
          description: json['description'],
        ),
      );
      
      return Response(
        201,
        body: jsonEncode({
          'success': true,
          'data': category?.toJson() ?? {},
          'message': 'Company expense category created successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create company expense category: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _approveExpense(Request request, String id, String type) async {
    try {
      final expenseId = int.parse(id);
      final result = await _expenseService.approveExpense(type, expenseId, request.authUserId, request.authUserRole ?? '');
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Approval failed: $e'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _rejectExpense(Request request, String id, String type) async {
    try {
      final expenseId = int.parse(id);
      final result = await _expenseService.rejectExpense(type, expenseId, request.authUserId);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Rejection failed: $e'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Router get router {
    return _router;
  }
}
