import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/expense_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../data/models/expense_model.dart';

class CompanyExpensesRoutes {
  final ExpenseService _expenseService = ExpenseService();
  final Router _router = Router();

  CompanyExpensesRoutes() {
    _setupRoutes();
  }

  void _setupRoutes() {
    // Company expenses routes
    _router.get('/', _getAllCompanyExpenses);
    _router.get('/<id>', _getCompanyExpenseById);
    _router.post('/', _createCompanyExpense);
    _router.put('/<id>', _updateCompanyExpense);
    _router.delete('/<id>', _deleteCompanyExpense);
    _router.get('/summary', _getCompanyExpenseSummary);

    // Company expense categories routes
    _router.get('/categories', _getCompanyExpenseCategories);
    _router.post('/categories', _createCompanyExpenseCategory);
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
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve company expenses: $e',
        }),
        headers: {'content-type': 'application/json'},
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
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': expense?.toJson() ?? {},
          'message': 'Company expense retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve company expense: $e',
        }),
        headers: {'content-type': 'application/json'},
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
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create company expense: $e',
        }),
        headers: {'content-type': 'application/json'},
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
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to update company expense: $e',
        }),
        headers: {'content-type': 'application/json'},
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
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to delete company expense: $e',
        }),
        headers: {'content-type': 'application/json'},
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
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve company expense summary: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // Company expense categories handlers
  Future<Response> _getCompanyExpenseCategories(Request request) async {
    try {
      final categories = await _expenseService.getExpenseCategories();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': categories.map((c) => c?.toJson() ?? {}).toList(),
          'message': 'Company expense categories retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve company expense categories: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _createCompanyExpenseCategory(Request request) async {
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
          'message': 'Company expense category created successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create company expense category: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Router get router {
    return _router;
  }
}
