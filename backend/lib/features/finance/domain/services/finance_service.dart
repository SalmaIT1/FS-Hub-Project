import '../../data/repositories/finance_repository.dart';
import '../../../project/data/repositories/project_repository.dart';

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
    await _repository.createPayment(data);
  }

  static Future<void> deletePayment(int id) async {
    await _repository.deletePayment(id);
  }
}
