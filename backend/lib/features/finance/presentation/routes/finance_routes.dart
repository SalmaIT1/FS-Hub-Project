import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/finance_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';
import '../../../../core/middleware/rate_limit_middleware.dart';
import '../../../../core/middleware/idempotency_middleware.dart';
import '../../../client/domain/services/client_service.dart';

class FinanceRoutes {
  late final Router router;

  FinanceRoutes() {
    final secured = Pipeline().addMiddleware(requireAuth());
    router = Router()
      ..get('/invoices', secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('view_invoices')).addHandler(_getAllInvoices))
      ..get('/invoices/mine', secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('view_invoices')).addHandler(_getMyInvoices))
      ..get('/invoices/project/<projectId>', (Request request, String projectId) => secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('view_invoices')).addHandler((req) => _getInvoicesByProject(req, projectId))(request))
      ..get('/invoices/<id>', (Request request, String id) => secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('view_invoices')).addHandler((req) => _getInvoiceById(req, id))(request))
      ..post('/invoices', secured.addMiddleware(rateLimit(maxAttempts: 50)).addMiddleware(idempotency()).addMiddleware(requirePermission('manage_invoices')).addHandler(_createInvoice))
      ..put('/invoices/<id>', (Request request, String id) => secured.addMiddleware(rateLimit(maxAttempts: 50)).addMiddleware(requirePermission('manage_invoices')).addHandler((req) => _updateInvoice(req, id))(request))
      ..delete('/invoices/<id>', (Request request, String id) => secured.addMiddleware(rateLimit(maxAttempts: 10)).addMiddleware(requirePermission('manage_invoices')).addHandler((req) => _deleteInvoice(req, id))(request))
      ..get('/summary', secured.addMiddleware(rateLimit(maxAttempts: 200)).addMiddleware(requirePermission('view_revenue')).addHandler(_getFinanceSummary))
      ..get('/summary/mine', secured.addMiddleware(rateLimit(maxAttempts: 200)).addMiddleware(requirePermission('view_invoices')).addHandler(_getMySummary))
      ..get('/payments/invoice/<invoiceId>', (Request request, String invoiceId) => secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('view_invoices')).addHandler((req) => _getPaymentsByInvoice(req, invoiceId))(request))
      ..post('/payments', secured.addMiddleware(rateLimit(maxAttempts: 50)).addMiddleware(idempotency()).addMiddleware(requirePermission('manage_payments')).addHandler(_createPayment))
      ..delete('/payments/<id>', (Request request, String id) => secured.addMiddleware(rateLimit(maxAttempts: 10)).addMiddleware(requirePermission('manage_payments')).addHandler((req) => _deletePayment(req, id))(request))
      
      // Quotes (Devis) endpoints
      ..get('/quotes', secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('manage_quotes')).addHandler(_getAllQuotes))
      ..get('/quotes/mine', secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('view_quotes')).addHandler(_getMyQuotes))
      ..get('/quotes/client/<clientId>', (Request request, String clientId) => secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('view_quotes')).addHandler((req) => _getQuotesByClient(req, clientId))(request))
      ..get('/quotes/<id>', (Request request, String id) => secured.addMiddleware(rateLimit(maxAttempts: 100)).addMiddleware(requirePermission('view_quotes')).addHandler((req) => _getQuoteById(req, id))(request))
      ..post('/quotes', secured.addMiddleware(rateLimit(maxAttempts: 50)).addMiddleware(idempotency()).addMiddleware(requirePermission('manage_quotes')).addHandler(_createQuote))
      ..put('/quotes/<id>', (Request request, String id) => secured.addMiddleware(rateLimit(maxAttempts: 50)).addMiddleware(requirePermission('manage_quotes')).addHandler((req) => _updateQuote(req, id))(request))
      ..post('/quotes/<id>/approve', (Request request, String id) => secured.addMiddleware(rateLimit(maxAttempts: 20)).addMiddleware(requirePermission('view_quotes')).addHandler((req) => _approveQuoteFromClient(req, id))(request))
      ..delete('/quotes/<id>', (Request request, String id) => secured.addMiddleware(rateLimit(maxAttempts: 10)).addMiddleware(requirePermission('manage_quotes')).addHandler((req) => _deleteQuote(req, id))(request));
  }

  Future<Response> _getFinanceSummary(Request request) async {
    try {
      final summary = await FinanceService.getFinanceSummary();
      return Response.ok(jsonEncode(summary), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getMySummary(Request request) async {
    try {
      final userId = request.authUserId;
      final client = await ClientService.getClientByUserId(userId);
      if (client == null || client['id'] == null) return Response.notFound(jsonEncode({'error': 'Client profile not found'}));
      
      final summary = await FinanceService.getClientSummary(client['id']);
      return Response.ok(jsonEncode({'success': true, 'data': summary}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getAllInvoices(Request request) async {
    try {
      final invoices = await FinanceService.getAllInvoices();
      return Response.ok(jsonEncode({'success': true, 'data': invoices}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getMyInvoices(Request request) async {
    try {
      final userId = request.authUserId;
      
      final client = await ClientService.getClientByUserId(userId);
      if (client == null || client['id'] == null) return Response.notFound(jsonEncode({'error': 'Client profile not found'}));
      
      final invoices = await FinanceService.getInvoicesByClient(client['id']);
      return Response.ok(jsonEncode({'success': true, 'data': invoices}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getInvoicesByProject(Request request, String projectId) async {
    try {
      final pid = int.tryParse(projectId);
      if (pid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      final invoices = await FinanceService.getInvoicesByProject(
        pid,
        callerRole: request.authUserRole,
        callerId: request.authUserId,
      );
      return Response.ok(jsonEncode({'success': true, 'data': invoices}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getInvoiceById(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      final invoice = await FinanceService.getInvoiceById(
        id,
        callerRole: request.authUserRole,
        callerId: request.authUserId,
      );
      if (invoice == null) return Response.notFound(jsonEncode({'error': 'Invoice not found or access denied'}));
      return Response.ok(jsonEncode(invoice), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _createInvoice(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      await FinanceService.createInvoice(data);
      return Response(201, body: jsonEncode({'success': true, 'message': 'Invoice created'}));
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      final status = e is Exception ? 400 : 500;
      return Response(
        status,
        body: jsonEncode({'success': false, 'message': message}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _updateInvoice(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      final data = jsonDecode(await request.readAsString());
      await FinanceService.updateInvoice(id, data);
      return Response.ok(jsonEncode({'success': true, 'message': 'Invoice updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _deleteInvoice(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      await FinanceService.deleteInvoice(id);
      return Response.ok(jsonEncode({'success': true, 'message': 'Invoice deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getPaymentsByInvoice(Request request, String invoiceId) async {
    try {
      final iid = int.tryParse(invoiceId);
      if (iid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      final payments = await FinanceService.getPaymentsByInvoice(
        iid,
        callerRole: request.authUserRole,
        callerId: request.authUserId,
      );
      return Response.ok(jsonEncode({'success': true, 'data': payments}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _createPayment(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      await FinanceService.createPayment(data);
      return Response(201, body: jsonEncode({'success': true, 'message': 'Payment recorded'}));
    } catch (e) {
      // Differentiate between known business logic exceptions and unexpected errors
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('Overpayment') || errorMsg.contains('duplicate') || errorMsg.contains('required')) {
        return Response.badRequest(body: jsonEncode({'success': false, 'message': errorMsg}));
      }
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal financial processing error'}));
    }
  }

  Future<Response> _deletePayment(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      await FinanceService.deletePayment(id);
      return Response.ok(jsonEncode({'success': true, 'message': 'Payment deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  // ---- Quotes (Devis) Handlers ----

  Future<Response> _getAllQuotes(Request request) async {
    try {
      final quotes = await FinanceService.getAllQuotes();
      return Response.ok(jsonEncode({'success': true, 'data': quotes}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getMyQuotes(Request request) async {
    try {
      final userId = request.authUserId;
      
      final client = await ClientService.getClientByUserId(userId);
      if (client == null || client['id'] == null) return Response.notFound(jsonEncode({'error': 'Client profile not found'}));
      
      final quotes = await FinanceService.getQuotesByClient(client['id']);
      return Response.ok(jsonEncode({'success': true, 'data': quotes}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getQuotesByClient(Request request, String clientId) async {
    try {
      final cid = int.tryParse(clientId);
      if (cid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid client ID'}));
      final quotes = await FinanceService.getQuotesByClient(cid);
      return Response.ok(jsonEncode({'success': true, 'data': quotes}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getQuoteById(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      final quote = await FinanceService.getQuoteById(id);
      if (quote == null) return Response.notFound(jsonEncode({'error': 'Quote not found'}));
      return Response.ok(jsonEncode(quote), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _createQuote(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      await FinanceService.createQuote(data);
      return Response(201, body: jsonEncode({'success': true, 'message': 'Quote created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _updateQuote(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      final data = jsonDecode(await request.readAsString());
      await FinanceService.updateQuote(id, data);
      return Response.ok(jsonEncode({'success': true, 'message': 'Quote updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _approveQuoteFromClient(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      // SECURITY FIX: Verify client owns quote in FinanceService
      await FinanceService.approveQuote(
        id, 
        callerId: request.authUserId, 
        callerRole: request.authUserRole
      );
      
      return Response.ok(jsonEncode({'success': true, 'message': 'Quote approved successfully'}));
    } catch (e) {
      return Response(403, body: jsonEncode({'success': false, 'message': e.toString().replaceFirst('Exception: ', '')}));
    }
  }

  Future<Response> _deleteQuote(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      await FinanceService.deleteQuote(id);
      return Response.ok(jsonEncode({'success': true, 'message': 'Quote deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }
}
