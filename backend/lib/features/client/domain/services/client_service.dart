import '../../data/repositories/client_repository.dart';
import '../../../../core/services/credit_score_service.dart';
import '../../../../shared/services/audit_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class ClientService {
  static final _repository = ClientRepository();

  static Future<List<Map<String, dynamic>>> getAllClients() async {
    final clients = await _repository.getAllClients();
    return clients.map((c) => c.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getClientById(int id) async {
    final client = await _repository.getClientById(id);
    return client?.toJson();
  }

  static Future<Map<String, dynamic>> createClient(Map<String, dynamic> data, {String? callerId}) async {
    final id = await _repository.createClient(data);
    final client = await _repository.getClientById(id);
    if (callerId != null) {
      await AuditService.log(callerId, 'CLIENT_CREATED', {
        'clientId': id,
        'nom': data['nom'],
      });
    }
    return client?.toJson() ?? {};
  }

  static Future<Map<String, dynamic>> updateClient(int id, Map<String, dynamic> data, {String? callerId}) async {
    await _repository.updateClient(id, data);
    final client = await _repository.getClientById(id);
    if (callerId != null) {
      await AuditService.log(callerId, 'CLIENT_UPDATED', {
        'clientId': id,
        'fields': data.keys.toList(),
      });
    }
    return client?.toJson() ?? {};
  }

  static Future<bool> deleteClient(int id, {String? callerId}) async {
    final client = await _repository.getClientById(id);
    final ok = await _repository.deleteClient(id);
    if (ok && callerId != null) {
      await AuditService.log(callerId, 'CLIENT_DELETED', {
        'clientId': id,
        'nom': client?.nom,
      });
    }
    return ok;
  }

  static Future<Map<String, dynamic>> getClientCreditScore(int id) async {
    return await CreditScoreService.calculateClientCreditScore(id);
  }

  static Future<Map<String, dynamic>> getAllClientsWithCreditScores() async {
    return await CreditScoreService.getAllClientsWithCreditScores();
  }

  static Future<Map<String, dynamic>> getPaymentHistory(int id) async {
    return await CreditScoreService.getProjectPaymentHistory(id);
  }
}
