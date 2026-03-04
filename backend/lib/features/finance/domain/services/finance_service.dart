import '../../data/repositories/finance_repository.dart';

class FinanceService {
  static final _repository = FinanceRepository();

  static Future<Map<String, dynamic>> getFinanceSummary() async {
    return await _repository.getFinanceSummary();
  }

  static Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final invoices = await _repository.getAllInvoices();
    return invoices.map((i) => i.toJson()).toList();
  }

  static Future<List<Map<String, dynamic>>> getInvoicesByProject(int projectId) async {
    final invoices = await _repository.getInvoicesByProject(projectId);
    return invoices.map((i) => i.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getInvoiceById(int id) async {
    final invoice = await _repository.getInvoiceById(id);
    return invoice?.toJson();
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

  static Future<List<Map<String, dynamic>>> getPaymentsByInvoice(int invoiceId) async {
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
