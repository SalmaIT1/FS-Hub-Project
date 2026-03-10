import '../../data/models/credit_model.dart';
import '../../data/repositories/credit_repository.dart';

class CreditService {
  final CreditRepository _repository = CreditRepository();

  Future<List<CreditModel>> getAllCredits() {
    return _repository.getAllCredits();
  }

  Future<CreditModel?> getCreditById(int id) {
    return _repository.getCreditById(id);
  }

  Future<CreditModel> createCredit(CreditModel credit) {
    return _repository.createCredit(credit);
  }

  Future<CreditModel> updateCredit(CreditModel credit) {
    return _repository.updateCredit(credit);
  }

  Future<bool> deleteCredit(int id) {
    return _repository.deleteCredit(id);
  }

  Future<List<CreditModel>> getProjectCredits(int projectId) {
    return _repository.getProjectCredits(projectId);
  }

  Future<List<CreditModel>> getClientCredits(int clientId) {
    return _repository.getClientCredits(clientId);
  }

  Future<Map<String, dynamic>> getCreditSummary() {
    return _repository.getCreditSummary();
  }

  Future<Map<String, dynamic>> getProjectCreditSummary(int projectId) {
    return _repository.getProjectCreditSummary(projectId);
  }

  Future<Map<String, dynamic>> getClientCreditSummary(int clientId) {
    return _repository.getClientCreditSummary(clientId);
  }

  Future<Map<String, dynamic>> getClientCreditLimit(int clientId) {
    return _repository.getClientCreditLimit(clientId);
  }

  Future<bool> updateClientCreditLimit(int clientId, double newLimit) {
    return _repository.updateClientCreditLimit(clientId, newLimit);
  }

  Future<bool> applyCreditToProject(int creditId, int projectId, double amount) {
    return _repository.applyCreditToProject(creditId, projectId, amount);
  }

  Future<bool> applyCreditToInvoice(int creditId, int invoiceId, double amount) {
    return _repository.applyCreditToInvoice(creditId, invoiceId, amount);
  }

  // Utility methods
  Future<List<Map<String, dynamic>>> getAllCreditsWithDetails() async {
    final credits = await getAllCredits();
    return credits.map((credit) => credit.toJson()).toList();
  }

  Future<Map<String, dynamic>> createCreditFromJson(Map<String, dynamic> json) async {
    try {
      final credit = CreditModel(
        type: json['type'] ?? '',
        montant: (json['montant'] as num).toDouble(),
        dateCredit: DateTime.parse(json['date_credit']),
        description: json['description'],
        clientId: json['client_id'],
        projectId: json['projet_id'],
        invoiceId: json['invoice_id'],
        createdBy: json['created_by'],
      );

      final createdCredit = await createCredit(credit);
      
      return {
        'success': true,
        'message': 'Credit created successfully',
        'data': createdCredit.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create credit: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> updateCreditFromJson(int id, Map<String, dynamic> json) async {
    try {
      final credit = CreditModel(
        id: id,
        type: json['type'] ?? '',
        montant: (json['montant'] as num).toDouble(),
        dateCredit: DateTime.parse(json['date_credit']),
        description: json['description'],
        clientId: json['client_id'],
        projectId: json['projet_id'],
        invoiceId: json['invoice_id'],
      );

      final updatedCredit = await updateCredit(credit);
      
      return {
        'success': true,
        'message': 'Credit updated successfully',
        'data': updatedCredit.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update credit: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> deleteCreditWithResponse(int id) async {
    try {
      final success = await deleteCredit(id);
      return {
        'success': success,
        'message': success ? 'Credit deleted successfully' : 'Credit not found',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete credit: $e',
      };
    }
  }

  Future<Map<String, dynamic>> applyCreditToProjectWithResponse(int creditId, int projectId, double amount) async {
    try {
      final success = await applyCreditToProject(creditId, projectId, amount);
      return {
        'success': success,
        'message': success ? 'Credit applied to project successfully' : 'Failed to apply credit to project',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to apply credit to project: $e',
      };
    }
  }

  Future<Map<String, dynamic>> applyCreditToInvoiceWithResponse(int creditId, int invoiceId, double amount) async {
    try {
      final success = await applyCreditToInvoice(creditId, invoiceId, amount);
      return {
        'success': success,
        'message': success ? 'Credit applied to invoice successfully' : 'Failed to apply credit to invoice',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to apply credit to invoice: $e',
      };
    }
  }
}
