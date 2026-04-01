import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/expense_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../data/models/expense_model.dart';

class ProjectExpensesRoutes {
  final ExpenseService _expenseService = ExpenseService();
  final Router _router = Router();

  ProjectExpensesRoutes() {
    _setupRoutes();
  }

  void _setupRoutes() {
    // Project expenses routes
    _router.get('/', _getAllProjectExpenses);
    _router.get('/<id>', _getProjectExpenseById);
    _router.post('/', _createProjectExpense);
    _router.put('/<id>', _updateProjectExpense);
    _router.delete('/<id>', _deleteProjectExpense);
    _router.get('/summary', _getProjectExpenseSummary);

    // Project expense categories routes
    _router.get('/categories', _getExpenseCategories);
    _router.post('/categories', _createExpenseCategory);
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

  // Project expense categories handlers
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

  Router get router {
    return _router;
  }
}
