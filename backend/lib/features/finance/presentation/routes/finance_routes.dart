import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/finance_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';
import '../../../client/domain/services/client_service.dart';

class FinanceRoutes {
  late final Router router;

  FinanceRoutes() {
    router = Router()
      ..get('/invoices', Pipeline().addMiddleware(requirePermission('view_invoices')).addHandler(_getAllInvoices))
      ..get('/invoices/project/<projectId>', (Request request, String projectId) => Pipeline().addMiddleware(requirePermission('view_invoices')).addHandler((req) => _getInvoicesByProject(req, projectId))(request))
      ..get('/invoices/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_invoices')).addHandler((req) => _getInvoiceById(req, id))(request))
      ..post('/invoices', Pipeline().addMiddleware(requirePermission('manage_invoices')).addHandler(_createInvoice))
      ..put('/invoices/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_invoices')).addHandler((req) => _updateInvoice(req, id))(request))
      ..delete('/invoices/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_invoices')).addHandler((req) => _deleteInvoice(req, id))(request))
      ..get('/summary', Pipeline().addMiddleware(requirePermission('view_revenue')).addHandler(_getFinanceSummary))
      ..get('/payments/invoice/<invoiceId>', (Request request, String invoiceId) => Pipeline().addMiddleware(requirePermission('view_invoices')).addHandler((req) => _getPaymentsByInvoice(req, invoiceId))(request))
      ..post('/payments', Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler(_createPayment))
      ..delete('/payments/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_payments')).addHandler((req) => _deletePayment(req, id))(request))
      
      // Quotes (Devis) endpoints
      ..get('/quotes', Pipeline().addMiddleware(requirePermission('manage_quotes')).addHandler(_getAllQuotes))
      ..get('/quotes/mine', Pipeline().addMiddleware(requirePermission('view_quotes')).addHandler(_getMyQuotes))
      ..get('/quotes/client/<clientId>', (Request request, String clientId) => Pipeline().addMiddleware(requirePermission('view_quotes')).addHandler((req) => _getQuotesByClient(req, clientId))(request))
      ..get('/quotes/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_quotes')).addHandler((req) => _getQuoteById(req, id))(request))
      ..post('/quotes', Pipeline().addMiddleware(requirePermission('manage_quotes')).addHandler(_createQuote))
      ..put('/quotes/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_quotes')).addHandler((req) => _updateQuote(req, id))(request))
      ..post('/quotes/<id>/approve', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_quotes')).addHandler((req) => _approveQuoteFromClient(req, id))(request))
      ..delete('/quotes/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_quotes')).addHandler((req) => _deleteQuote(req, id))(request));
  }

  Future<Response> _getFinanceSummary(Request request) async {
    try {
      final summary = await FinanceService.getFinanceSummary();
      return Response.ok(jsonEncode(summary), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getAllInvoices(Request request) async {
    try {
      final invoices = await FinanceService.getAllInvoices();
      return Response.ok(jsonEncode(invoices), headers: {'Content-Type': 'application/json; charset=utf-8'});
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
      return Response.ok(jsonEncode(invoices), headers: {'Content-Type': 'application/json; charset=utf-8'});
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
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
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
      return Response.ok(jsonEncode(payments), headers: {'Content-Type': 'application/json; charset=utf-8'});
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
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
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
      return Response.ok(jsonEncode(quotes), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getMyQuotes(Request request) async {
    try {
      final userId = request.authUserId;
      if (userId == null) return Response.forbidden(jsonEncode({'error': 'Unauthorized access'}));
      
      final client = await ClientService.getClientByUserId(userId);
      if (client == null || client['id'] == null) return Response.notFound(jsonEncode({'error': 'Client profile not found'}));
      
      final quotes = await FinanceService.getQuotesByClient(client['id']);
      return Response.ok(jsonEncode(quotes), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getQuotesByClient(Request request, String clientId) async {
    try {
      final cid = int.tryParse(clientId);
      if (cid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid client ID'}));
      final quotes = await FinanceService.getQuotesByClient(cid);
      return Response.ok(jsonEncode(quotes), headers: {'Content-Type': 'application/json; charset=utf-8'});
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
      
      // Additional check to verify client owns quote can be added here
      await FinanceService.approveQuote(id);
      
      return Response.ok(jsonEncode({'success': true, 'message': 'Quote approved by client'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
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
