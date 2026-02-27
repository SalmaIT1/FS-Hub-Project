import 'dart:convert';
import 'package:mysql_client/mysql_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';
import '../services/credit_score_service.dart';

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

  // Helper function to convert database type to frontend enum format
  String _convertTypeToFrontend(String dbType) {
    if (dbType == 'Entreprise') {
      return 'entreprise';
    } else if (dbType == 'Particulier') {
      return 'particulier';
    }
    return 'particulier'; // default
  }

  Future<Response> _getAllClients(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit
        FROM clients
        ORDER BY id DESC
      ''');

      final clients = result.rows.map((row) {
        return {
          'id': int.tryParse(row.colByName('id').toString()) ?? 0,
          'nom': row.colByName('nom'),
          'prenom': row.colByName('prenom'),
          'raison_sociale': row.colByName('raison_sociale'),
          'email': row.colByName('email'),
          'telephone': row.colByName('telephone'),
          'type': _convertTypeToFrontend(row.colByName('type')),
          'score_credit': int.tryParse(row.colByName('score_credit').toString()) ?? 0,
        };
      }).toList();

      return Response.ok(
        jsonEncode(clients),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load clients: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getClientById(Request request) async {
    try {
      final id = int.parse(request.params['id']!);
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit
        FROM clients
        WHERE id = :id
      ''', {'id': id});

      if (result.rows.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Client not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final client = {
        'id': int.tryParse(result.rows.first.colByName('id').toString()) ?? 0,
        'nom': result.rows.first.colByName('nom'),
        'prenom': result.rows.first.colByName('prenom'),
        'raison_sociale': result.rows.first.colByName('raison_sociale'),
        'email': result.rows.first.colByName('email'),
        'telephone': result.rows.first.colByName('telephone'),
        'type': _convertTypeToFrontend(result.rows.first.colByName('type')),
        'score_credit': int.tryParse(result.rows.first.colByName('score_credit').toString()) ?? 0,
      };

      return Response.ok(
        jsonEncode(client),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load client: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _createClient(Request request) async {
    try {
      print('=== Client Creation Request ===');
      final body = await request.readAsString();
      print('Received client data: $body');
      
      final data = jsonDecode(body);
      print('Parsed client data: $data');
      
      // Convert type from lowercase to database ENUM format
      String clientType = data['type'] ?? 'Particulier';
      if (clientType == 'entreprise') {
        clientType = 'Entreprise';
      } else if (clientType == 'particulier') {
        clientType = 'Particulier';
      }
      print('Converted client type: $clientType');
      
      final conn = DBConnection.getConnection();
      print('Database connection obtained');
      
      final result = await conn.execute('''
        INSERT INTO clients (nom, prenom, raison_sociale, email, telephone, type, score_credit)
        VALUES (:nom, :prenom, :raison_sociale, :email, :telephone, :type, 0)
      ''', {
        'nom': data['nom'],
        'prenom': data['prenom'],
        'raison_sociale': data['raison_sociale'],
        'email': data['email'],
        'telephone': data['telephone'],
        'type': clientType,
      });
      print('Insert result: $result');

      // Get the last inserted ID using a separate query
      final idResult = await conn.execute('SELECT LAST_INSERT_ID() as id');
      final clientId = idResult.rows.first.colByName('id');
      print('Generated client ID: $clientId');
      
      final newClientResult = await conn.execute('''
        SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit
        FROM clients
        WHERE id = :id
      ''', {'id': clientId});

      final newClient = {
        'id': int.tryParse(newClientResult.rows.first.colByName('id').toString()) ?? 0,
        'nom': newClientResult.rows.first.colByName('nom'),
        'prenom': newClientResult.rows.first.colByName('prenom'),
        'raison_sociale': newClientResult.rows.first.colByName('raison_sociale'),
        'email': newClientResult.rows.first.colByName('email'),
        'telephone': newClientResult.rows.first.colByName('telephone'),
        'type': _convertTypeToFrontend(newClientResult.rows.first.colByName('type')),
        'score_credit': int.tryParse(newClientResult.rows.first.colByName('score_credit').toString()) ?? 0,
      };

      print('Response data: $newClient');
      final responseJson = jsonEncode(newClient);
      print('Response JSON: $responseJson');

      return Response(
        201,
        body: responseJson,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('=== ERROR IN CLIENT CREATION ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to create client: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _updateClient(Request request) async {
    try {
      final id = int.parse(request.params['id']!);
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      // Convert type from lowercase to database ENUM format
      String clientType = data['type'];
      if (clientType == 'entreprise') {
        clientType = 'Entreprise';
      } else if (clientType == 'particulier') {
        clientType = 'Particulier';
      }
      
      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        UPDATE clients 
        SET nom = :nom, prenom = :prenom, raison_sociale = :raison_sociale, email = :email, telephone = :telephone, type = :type
        WHERE id = :id
      ''', {
        'nom': data['nom'],
        'prenom': data['prenom'],
        'raison_sociale': data['raison_sociale'],
        'email': data['email'],
        'telephone': data['telephone'],
        'type': clientType,
        'id': id,
      });

      final updatedClientResult = await conn.execute('''
        SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit
        FROM clients
        WHERE id = :id
      ''', {'id': id});

      final updatedClient = {
        'id': int.tryParse(updatedClientResult.rows.first.colByName('id').toString()) ?? 0,
        'nom': updatedClientResult.rows.first.colByName('nom'),
        'prenom': updatedClientResult.rows.first.colByName('prenom'),
        'raison_sociale': updatedClientResult.rows.first.colByName('raison_sociale'),
        'email': updatedClientResult.rows.first.colByName('email'),
        'telephone': updatedClientResult.rows.first.colByName('telephone'),
        'type': _convertTypeToFrontend(updatedClientResult.rows.first.colByName('type')),
        'score_credit': int.tryParse(updatedClientResult.rows.first.colByName('score_credit').toString()) ?? 0,
      };

      return Response.ok(
        jsonEncode(updatedClient),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update client: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _deleteClient(Request request) async {
    try {
      final id = int.parse(request.params['id']!);
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        DELETE FROM clients WHERE id = :id
      ''', {'id': id});

      if (result.affectedRows == 0) {
        return Response.notFound(
          jsonEncode({'error': 'Client not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'message': 'Client deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete client: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // GET /v1/clients/<id>/credit-score - Calculate and get client credit score
  Future<Response> _getClientCreditScore(Request request) async {
    try {
      final id = int.parse(request.params['id']!);
      
      final result = await CreditScoreService.calculateClientCreditScore(id);
      
      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          jsonEncode({'message': result['message'] ?? 'Client not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to calculate credit score: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // GET /v1/clients/with-credit-scores - Get all clients with their credit scores
  Future<Response> _getAllClientsWithCreditScores(Request request) async {
    try {
      final result = await CreditScoreService.getAllClientsWithCreditScores();
      
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to fetch clients with credit scores: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // GET /v1/clients/<id>/payment-history - Get client's project payment history
  Future<Response> _getPaymentHistory(Request request) async {
    try {
      final id = int.parse(request.params['id']!);
      
      final result = await CreditScoreService.getProjectPaymentHistory(id);
      
      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          jsonEncode({'message': result['message'] ?? 'Client not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to fetch payment history: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
