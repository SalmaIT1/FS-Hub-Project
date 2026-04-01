import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/credit_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';
import '../../data/models/credit_model.dart';

class CreditRoutes {
  final CreditService _creditService = CreditService();
  final Router _router = Router();

  CreditRoutes() {
    _setupRoutes();
  }

  void _setupRoutes() {
    // Credit routes
    _router.get('/', Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler(_getAllCredits));
    _router.get('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler((req) => _getCreditById(req, id))(request));
    _router.post('/', Pipeline().addMiddleware(requirePermission('manage_credits')).addHandler(_createCredit));
    _router.put('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_credits')).addHandler((req) => _updateCredit(req, id))(request));
    _router.delete('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_credits')).addHandler((req) => _deleteCredit(req, id))(request));

    // Project credits routes
    _router.get('/project/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler((req) => _getProjectCredits(req, id))(request));
    
    // Client credits routes
    _router.get('/client/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler((req) => _getClientCredits(req, id))(request));
    
    // Summary routes
    _router.get('/summary', Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler(_getCreditSummary));
    _router.get('/project/<id>/summary', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler((req) => _getProjectCreditSummary(req, id))(request));
    _router.get('/client/<id>/summary', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler((req) => _getClientCreditSummary(req, id))(request));
    
    // Credit limit routes
    _router.get('/client/<id>/limit', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_financial_reports')).addHandler((req) => _getClientCreditLimit(req, id))(request));
    _router.put('/client/<id>/limit', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_credits')).addHandler((req) => _updateClientCreditLimit(req, id))(request));
    
    // Application routes
    _router.post('/<id>/apply/project', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_credits')).addHandler((req) => _applyCreditToProject(req, id))(request));
    _router.post('/<id>/apply-invoice', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_credits')).addHandler((req) => _applyCreditToInvoice(req, id))(request));
  }

  // Credit handlers
  Future<Response> _getAllCredits(Request request) async {
    try {
      final credits = await _creditService.getAllCreditsWithDetails();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': credits,
          'message': 'Credits retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve credits: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getCreditById(Request request, String id) async {
    try {
      final creditId = int.parse(id);
      final credit = await _creditService.getCreditById(creditId);
      
      if (credit == null) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'Credit not found',
          }),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': credit.toJson(),
          'message': 'Credit retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve credit: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _createCredit(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      // Add created_by from authenticated user
      final user = request.context['user'] as Map<String, dynamic>?;
      if (user != null) {
        json['created_by'] = user['username'];
      }
      
      final result = await _creditService.createCreditFromJson(json);
      
      return Response(
        result['success'] ? 201 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create credit: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _updateCredit(Request request, String id) async {
    try {
      final creditId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _creditService.updateCreditFromJson(creditId, json);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to update credit: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _deleteCredit(Request request, String id) async {
    try {
      final creditId = int.parse(id);
      final result = await _creditService.deleteCreditWithResponse(creditId);
      
      return Response(
        result['success'] ? 200 : 404,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to delete credit: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getProjectCredits(Request request, String id) async {
    try {
      final projectId = int.parse(id);
      final credits = await _creditService.getProjectCredits(projectId);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': credits.map((credit) => credit?.toJson() ?? {}).toList(),
          'message': 'Project credits retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve project credits: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getClientCredits(Request request, String id) async {
    try {
      final clientId = int.parse(id);
      final credits = await _creditService.getClientCredits(clientId);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': credits.map((credit) => credit?.toJson() ?? {}).toList(),
          'message': 'Client credits retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve client credits: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getCreditSummary(Request request) async {
    try {
      final summary = await _creditService.getCreditSummary();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': summary,
          'message': 'Credit summary retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve credit summary: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getProjectCreditSummary(Request request, String id) async {
    try {
      final projectId = int.parse(id);
      final summary = await _creditService.getProjectCreditSummary(projectId);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': summary,
          'message': 'Project credit summary retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve project credit summary: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getClientCreditSummary(Request request, String id) async {
    try {
      final clientId = int.parse(id);
      final summary = await _creditService.getClientCreditSummary(clientId);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': summary,
          'message': 'Client credit summary retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve client credit summary: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getClientCreditLimit(Request request, String id) async {
    try {
      final clientId = int.parse(id);
      final limit = await _creditService.getClientCreditLimit(clientId);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': limit,
          'message': 'Client credit limit retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve client credit limit: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _updateClientCreditLimit(Request request, String id) async {
    try {
      final clientId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final newLimit = double.parse(json['credit_limit'] as String);
      final success = await _creditService.updateClientCreditLimit(clientId, newLimit);
      
      return Response(
        success ? 200 : 400,
        body: jsonEncode({
          'success': success,
          'message': success ? 'Credit limit updated successfully' : 'Failed to update credit limit',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to update client credit limit: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _applyCreditToProject(Request request, String id) async {
    try {
      final creditId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final projectId = int.parse(json['project_id'] as String);
      final amount = (json['amount'] as num).toDouble();
      
      final result = await _creditService.applyCreditToProjectWithResponse(creditId, projectId, amount);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to apply credit to project: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _applyCreditToInvoice(Request request, String id) async {
    try {
      final creditId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final invoiceId = int.parse(json['invoice_id'] as String);
      final amount = (json['amount'] as num).toDouble();
      
      final result = await _creditService.applyCreditToInvoiceWithResponse(creditId, invoiceId, amount);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to apply credit to invoice: $e',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Router get router {
    return _router;
  }
}
