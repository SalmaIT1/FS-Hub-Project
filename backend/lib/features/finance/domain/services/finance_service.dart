import '../../data/repositories/finance_repository.dart';
import '../../../project/data/repositories/project_repository.dart';
import '../../../client/data/repositories/client_repository.dart';

class FinanceService {
  static final _repository = FinanceRepository();
  static final _projectRepo = ProjectRepository();

  static Future<Map<String, dynamic>> getFinanceSummary() async {
    return await _repository.getFinanceSummary();
  }

  static Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final invoices = await _repository.getAllInvoices();
    return invoices.map((i) => i.toJson()).toList();
  }

  static Future<List<Map<String, dynamic>>> getInvoicesByProject(int projectId, {String? callerRole, String? callerId}) async {
    // RBAC: Check if user belongs to project or is admin/finance role
    if (callerRole != 'Admin' && callerRole != 'Comptable' && callerRole != 'Manager' && callerId != null) {
      final isMember = await _projectRepo.isMember(projectId, callerId);
      if (!isMember) return [];
    }
    final invoices = await _repository.getInvoicesByProject(projectId);
    return invoices.map((i) => i.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getInvoiceById(int id, {String? callerRole, String? callerId}) async {
    final invoice = await _repository.getInvoiceById(id);
    if (invoice == null) return null;

    if (callerRole != 'Admin' && callerRole != 'Comptable' && callerRole != 'Manager' && callerId != null && invoice.projectId != null) {
      final isMember = await _projectRepo.isMember(invoice.projectId!, callerId);
      if (!isMember) return null;
    }
    
    return invoice.toJson();
  }

  static Future<void> createInvoice(Map<String, dynamic> data) async {
    final type = data['type'] ?? 'INVOICE';
    final timbre = double.tryParse(data['timbre']?.toString() ?? (type == 'DELIVERY_NOTE' ? '0' : '1')) ?? (type == 'DELIVERY_NOTE' ? 0.0 : 1.0);
    final projectId = data['projet_id'];

    if (type == 'INVOICE') {
      if (timbre != 1.0) {
        throw Exception("Invoice blocked: Timbre (1 TND) is mandatory.");
      }
    } else if (type == 'DELIVERY_NOTE') {
      if (timbre != 0.0) {
        throw Exception("Delivery note blocked: Timbre must be 0.");
      }
      if (projectId != null) {
        final project = await _projectRepo.getProjectById(projectId);
        if (project?.statut != 'Completed') {
          throw Exception("Delivery note blocked: Project must be completed.");
        }
      }
    }
    
    // Auto-inject timbre if not correctly passed in data but we validated
    data['timbre'] = timbre;
    await _repository.createInvoice(data);
  }

  static Future<void> updateInvoice(int id, Map<String, dynamic> data) async {
    await _repository.updateInvoice(id, data);
  }

  static Future<void> deleteInvoice(int id) async {
    await _repository.deleteInvoice(id);
  }

  static Future<List<Map<String, dynamic>>> getPaymentsByInvoice(int invoiceId, {String? callerRole, String? callerId}) async {
    final invoice = await _repository.getInvoiceById(invoiceId);
    if (invoice == null) return [];

    if (callerRole != 'Admin' && callerRole != 'Comptable' && callerRole != 'Manager' && callerId != null && invoice.projectId != null) {
      final isMember = await _projectRepo.isMember(invoice.projectId!, callerId);
      if (!isMember) return [];
    }

    final payments = await _repository.getPaymentsByInvoice(invoiceId);
    return payments.map((p) => p.toJson()).toList();
  }

  static Future<void> createPayment(Map<String, dynamic> data) async {
    final invoiceId = data['facture_id'];
    if (invoiceId != null) {
      final invoice = await _repository.getInvoiceById(int.parse(invoiceId.toString()));
      if (invoice != null && invoice.clientId != null) {
        final clientRepo = ClientRepository();
        final client = await clientRepo.getClientById(invoice.clientId!);
        if (client != null) {
          final paymentAmount = double.tryParse(data['montant']?.toString() ?? '0') ?? 0.0;
          final currentCredit = client.credit ?? 0.0;
          if (currentCredit - paymentAmount < 0) {
             throw Exception("Credit logic violation: Credit cannot be negative.");
          }
          await clientRepo.updateClient(invoice.clientId!, {
             'credit': currentCredit - paymentAmount,
          });
        }
      }
    }
    await _repository.createPayment(data);
  }

  static Future<void> deletePayment(int id) async {
    await _repository.deletePayment(id);
  }

  // ---- Quotes (Devis) Methods ----
  static Future<List<Map<String, dynamic>>> getAllQuotes() async {
    final quotes = await _repository.getAllQuotes();
    return quotes.map((q) => q.toJson()).toList();
  }

  static Future<List<Map<String, dynamic>>> getQuotesByClient(int clientId) async {
    final quotes = await _repository.getQuotesByClient(clientId);
    return quotes.map((q) => q.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getQuoteById(int id) async {
    final quote = await _repository.getQuoteById(id);
    return quote?.toJson();
  }

  static Future<void> createQuote(Map<String, dynamic> data) async {
    await _repository.createQuote(data);
  }

  static Future<void> updateQuote(int id, Map<String, dynamic> data) async {
    await _repository.updateQuote(id, data);
  }

  static Future<void> approveQuote(int id) async {
    await _repository.updateQuoteStatus(id, 'Accepté');
  }

  static Future<void> rejectQuote(int id) async {
    await _repository.updateQuoteStatus(id, 'Refusé');
  }

  static Future<void> deleteQuote(int id) async {
    await _repository.deleteQuote(id);
  }
}
