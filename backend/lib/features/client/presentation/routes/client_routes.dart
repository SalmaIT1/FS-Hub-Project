import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/client_service.dart';

class ClientRoutes {
  late final Router router;

  ClientRoutes() {
    router = Router()
      ..get('/', _getAllClients)
      ..get('/<id>', _getClientById)
      ..post('/', _createClient)
      ..put('/<id>', _updateClient)
      ..delete('/<id>', _deleteClient)
      ..get('/<id>/credit-score', _getClientCreditScore)
      ..get('/with-credit-scores', _getAllClientsWithCreditScores)
      ..get('/<id>/payment-history', _getPaymentHistory);
  }

  Future<Response> _getAllClients(Request request) async {
    try {
      final clients = await ClientService.getAllClients();
      return Response.ok(jsonEncode(clients), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to load clients: $e'}));
    }
  }

  Future<Response> _getClientById(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final client = await ClientService.getClientById(id);
      if (client == null) return Response.notFound(jsonEncode({'error': 'Client not found'}));
      
      return Response.ok(jsonEncode(client), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to load client: $e'}));
    }
  }

  Future<Response> _createClient(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      if (data['nom'] == null || data['email'] == null) {
        return Response(400, body: jsonEncode({'message': 'Name and Email are required'}));
      }
      
      final result = await ClientService.createClient(data);
      return Response(201, body: jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create: $e'}));
    }
  }

  Future<Response> _updateClient(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final result = await ClientService.updateClient(id, data);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to update: $e'}));
    }
  }

  Future<Response> _deleteClient(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final ok = await ClientService.deleteClient(id);
      if (!ok) return Response.notFound(jsonEncode({'error': 'Client not found'}));
      
      return Response.ok(jsonEncode({'message': 'Client deleted successfully'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to delete: $e'}));
    }
  }

  Future<Response> _getClientCreditScore(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final result = await ClientService.getClientCreditScore(id);
      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } else {
        return Response.notFound(jsonEncode(result));
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Failed: $e'}));
    }
  }

  Future<Response> _getAllClientsWithCreditScores(Request request) async {
    try {
      final result = await ClientService.getAllClientsWithCreditScores();
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Failed: $e'}));
    }
  }

  Future<Response> _getPaymentHistory(Request request, String idString) async {
    try {
      final id = int.tryParse(idString);
      if (id == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final result = await ClientService.getPaymentHistory(id);
      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } else {
        return Response.notFound(jsonEncode(result));
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Failed: $e'}));
    }
  }
}
