import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/client_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';

class ClientRoutes {
  late final Router router;

  ClientRoutes() {
    router = Router()
      ..get('/', Pipeline().addMiddleware(requireRoleOrPermission(['Admin', 'Manager', 'RH', 'Comptable'], ['view_clients'])).addHandler(_getAllClients))
      ..get('/<id>', (Request request, String id) => Pipeline().addMiddleware(requireRoleOrPermission(['Admin', 'Manager', 'RH', 'Comptable'], ['view_clients'])).addHandler((req) => _getClientById(req, id))(request))
      ..post('/', Pipeline().addMiddleware(requirePermission('manage_clients')).addHandler(_createClient))
      ..put('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_clients')).addHandler((req) => _updateClient(req, id))(request))
      ..delete('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_clients')).addHandler((req) => _deleteClient(req, id))(request))
      ..get('/<id>/credit-score', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_clients')).addHandler((req) => _getClientCreditScore(req, id))(request))
      ..get('/with-credit-scores', Pipeline().addMiddleware(requirePermission('view_clients')).addHandler(_getAllClientsWithCreditScores))
      ..patch('/<id>/score', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_clients')).addHandler((req) => _updateClientScore(req, id))(request))
      ..get('/<id>/payment-history', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_clients')).addHandler((req) => _getPaymentHistory(req, id))(request));
  }

  Future<Response> _getAllClients(Request request) async {
    try {
      final params = request.url.queryParameters;
      final type = params['type'];
      final search = params['search'];
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final offset = (page - 1) * limit;

      final clients = await ClientService.getAllClients(
        type: type,
        search: search,
        limit: limit,
        offset: offset,
      );
      return Response.ok(jsonEncode(clients), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getClientById(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final client = await ClientService.getClientById(id);
      if (client == null) return Response.notFound(jsonEncode({'error': 'Client not found'}));
      
      return Response.ok(jsonEncode(client), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _createClient(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      if (data['nom'] == null || data['email'] == null) {
        return Response(400, body: jsonEncode({'message': 'Name and Email are required'}));
      }
      
      final result = await ClientService.createClient(data, callerId: request.authUserId);
      return Response(201, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Internal server error'}));
    }
  }

  Future<Response> _updateClient(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final result = await ClientService.updateClient(id, data, callerId: request.authUserId);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _deleteClient(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final ok = await ClientService.deleteClient(id, callerId: request.authUserId);
      if (!ok) return Response.notFound(jsonEncode({'error': 'Client not found'}));
      
      return Response.ok(jsonEncode({'message': 'Client deleted successfully'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getClientCreditScore(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final result = await ClientService.getClientCreditScore(id);
      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response.notFound(jsonEncode(result));
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Internal server error'}));
    }
  }

  Future<Response> _updateClientScore(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final score = int.tryParse(data['score_credit']?.toString() ?? '0') ?? 0;
      
      final result = await ClientService.updateClient(id, {'score_credit': score}, callerId: request.authUserId);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Internal server error'}));
    }
  }

  Future<Response> _getAllClientsWithCreditScores(Request request) async {
    try {
      final result = await ClientService.getAllClientsWithCreditScores();
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Internal server error'}));
    }
  }

  Future<Response> _getPaymentHistory(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final result = await ClientService.getPaymentHistory(id);
      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response.notFound(jsonEncode(result));
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Internal server error'}));
    }
  }
}
