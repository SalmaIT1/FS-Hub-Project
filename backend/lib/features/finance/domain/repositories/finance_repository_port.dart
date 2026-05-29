import '../../data/models/finance_model.dart';

/// Finance persistence contract (enables mocktail fakes in service tests).
abstract class FinanceRepositoryPort {
  Future<void> createInvoice(Map<String, dynamic> data);
  Future<QuoteModel?> getQuoteById(int id);
  Future<InvoiceModel?> getInvoiceById(int id);
}
