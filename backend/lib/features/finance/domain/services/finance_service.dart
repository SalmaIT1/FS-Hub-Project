import '../../data/repositories/finance_repository.dart';
import '../../../project/data/repositories/project_repository.dart';
import '../../../client/domain/services/client_service.dart';
import '../../../../shared/database/connection.dart';

class FinanceService {
  static final _repository = FinanceRepository();
  static final _projectRepo = ProjectRepository();

  static Future<Map<String, dynamic>> getFinanceSummary() async {
    return await _repository.getFinanceSummary();
  }

  static Future<Map<String, dynamic>> getClientSummary(int clientId) async {
    return await _repository.getClientFinanceSummary(clientId);
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

  static Future<List<Map<String, dynamic>>> getInvoicesByClient(int clientId) async {
    final invoices = await _repository.getInvoicesByClient(clientId);
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

  static Future<void> createInvoice(Map<String, dynamic> rawData) async {
    // Sanitization: Extract only allowed fields to prevent injection
    final data = <String, dynamic>{
      'projet_id': rawData['projet_id'],
      'client_id': rawData['client_id'],
      'numero_facture': rawData['numero_facture'],
      'type': rawData['type'] ?? 'INVOICE',
      'montant_ht': rawData['montant_ht'],
      'tva': rawData['tva'],
      'timbre': rawData['timbre'],
      'montant_ttc': rawData['montant_ttc'],
      'date_emission': rawData['date_emission'],
      'date_echeance': rawData['date_echeance'],
      'statut': rawData['statut'] ?? 'Brouillon',
      'quote_id': rawData['quote_id'] ?? rawData['devis_id'],
    };

    final type = data['type'];
    final timbre = double.tryParse(data['timbre']?.toString() ?? (type == 'DELIVERY_NOTE' ? '0' : '1')) ?? (type == 'DELIVERY_NOTE' ? 0.0 : 1.0);
    final projectId = data['projet_id'];
    final quoteId = data['quote_id'];

    if (type == 'INVOICE') {
      if (timbre != 1.0) {
        throw Exception("Invoice blocked: Timbre (1 TND) is mandatory.");
      }
      if (quoteId != null) {
        final quote = await _repository.getQuoteById(int.parse(quoteId.toString()));
        if (quote == null || (quote.statut != 'Accepté' && quote.statut != 'Approved')) {
           throw Exception("Invoice blocked: Associated quote must be 'Accepté' (Approved).");
        }
        
        // Enforce quote totals and client mapping directly from backend (Source of Truth)
        data['client_id'] = quote.clientId;
        data['projet_id'] = quote.projectId;
        data['montant_ht'] = quote.montantHt;
        data['tva'] = quote.tva;
        data['montant_ttc'] = quote.montantTtc;
      }
    } else if (type == 'DELIVERY_NOTE') {
      if (timbre != 0.0) {
        throw Exception("Delivery note blocked: Timbre must be 0.");
      }
      if (projectId != null) {
        final pid = int.tryParse(projectId.toString());
        if (pid != null) {
           final project = await _projectRepo.getProjectById(pid);
           if (project?.statut != 'Completed') {
             throw Exception("Delivery note blocked: Project must be completed.");
           }
        }
      }
    }
    
    data['timbre'] = timbre;
    await _repository.createInvoice(data);
  }

  static Future<void> updateInvoice(int id, Map<String, dynamic> rawData) async {
    // Sanitization
    final data = <String, dynamic>{
      'numero_facture': rawData['numero_facture'],
      'montant_ht': rawData['montant_ht'],
      'tva': rawData['tva'],
      'montant_ttc': rawData['montant_ttc'],
      'date_emission': rawData['date_emission'],
      'date_echeance': rawData['date_echeance'],
      'statut': rawData['statut'],
    };

    // P0 FIX: Re-verify quote status even on update if it's linked
    final existing = await _repository.getInvoiceById(id);
    if (existing != null && existing.devisId != null) {
       final quote = await _repository.getQuoteById(existing.devisId!);
       if (quote == null || (quote.statut != 'Accepté' && quote.statut != 'Approved')) {
          throw Exception("Invoice update blocked: Associated quote is no longer in approved state.");
       }
    }

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

  static Future<void> createPayment(Map<String, dynamic> rawData) async {
    // Sanitization
    final data = <String, dynamic>{
      'facture_id': rawData['facture_id'],
      'montant': rawData['montant'],
      'mode': rawData['mode'],
      'date_paiement': rawData['date_paiement'],
      'reference_transaction': rawData['reference_transaction'],
    };

    final db = DBConnection.getConnection();
    
    await db.transaction((ctx) async {
      final invoiceId = data['facture_id'];
      if (invoiceId == null) throw Exception('facture_id is required');

      // Lock the invoice row and compute its remaining open balance
      final invoiceRes = await ctx.execute(
        'SELECT client_id, montant_ttc FROM factures WHERE id = :id FOR UPDATE',
        {'id': invoiceId},
      );
      if (invoiceRes.rows.isEmpty) throw Exception('Invoice not found');

      final invoiceRow = invoiceRes.rows.first;
      final clientId = invoiceRow.colByName('client_id')?.toString();
      final invoiceTtc = double.tryParse(invoiceRow.colByName('montant_ttc')?.toString() ?? '0') ?? 0.0;
      final paymentAmount = double.tryParse(data['montant']?.toString() ?? '0') ?? 0.0;

      if (paymentAmount <= 0) throw Exception('Payment amount must be positive');

      // Sum all prior payments
      final paidRes = await ctx.execute(
        'SELECT COALESCE(SUM(montant), 0) as total_paid FROM paiements WHERE facture_id = :id',
        {'id': invoiceId},
      );
      final alreadyPaid = double.tryParse(paidRes.rows.first.colByName('total_paid')?.toString() ?? '0') ?? 0.0;
      final remainingBalance = invoiceTtc - alreadyPaid;

      if (paymentAmount > remainingBalance + 0.001) {
        throw Exception(
          'Overpayment Error: Payment ($paymentAmount) exceeds balance ($remainingBalance). '
          'Invoice total: $invoiceTtc, paid: $alreadyPaid.',
        );
      }

      await ctx.execute('''
        INSERT INTO paiements (facture_id, montant, mode, date_paiement, reference_transaction, client_request_id)
        VALUES (:fid, :mnt, :mode, :date, :ref, :rid)
      ''', {
        'fid': invoiceId,
        'mnt': paymentAmount,
        'mode': data['mode'],
        'date': data['date_paiement'],
        'ref': data['reference_transaction'],
        'rid': data['client_request_id'],
      });
      
      // Note: Database triggers (trg_payment_after_insert) will automatically 
      // handle invoice status and client debt (solde_du).
    });
  }

  static Future<void> deletePayment(int id) async {
    final db = DBConnection.getConnection();
    
    await db.transaction((ctx) async {
      final paymentRes = await ctx.execute('SELECT * FROM paiements WHERE id = :id FOR UPDATE', {'id': id});
      if (paymentRes.rows.isEmpty) return;
      
      final row = paymentRes.rows.first.assoc();
      final factureIdStr = row['facture_id']?.toString();
      final factureId = factureIdStr != null ? int.tryParse(factureIdStr) : null;
      final montant = double.tryParse(row['montant']?.toString() ?? '0') ?? 0.0;

      if (factureId != null) {
      // Database triggers handle solde_du cleanup
      }
      
      await ctx.execute('DELETE FROM paiements WHERE id = :id', {'id': id});
      
      // Database triggers handle invoice status rollback
    });
  }

  /// P0-01 FIX: Centralized logic to harmonize invoice status based on current payments.
  static Future<void> _recalculateInvoiceStatus(dynamic ctx, int invoiceId) async {
    final invRes = await ctx.execute(
      'SELECT montant_ttc, statut FROM factures WHERE id = :id FOR UPDATE',
      {'id': invoiceId},
    );
    if (invRes.rows.isEmpty) return;

    final invoiceRow = invRes.rows.first;
    final ttc = double.tryParse(invoiceRow.colByName('montant_ttc')?.toString() ?? '0') ?? 0.0;
    
    final paidRes = await ctx.execute(
      'SELECT COALESCE(SUM(montant), 0) as total_paid FROM paiements WHERE facture_id = :id',
      {'id': invoiceId},
    );
    final totalPaid = double.tryParse(paidRes.rows.first.colByName('total_paid')?.toString() ?? '0') ?? 0.0;

    String newStatus;
    if (totalPaid <= 0) {
      newStatus = 'Envoyée'; // Return to an active but unpaid state
    } else if (totalPaid >= ttc - 0.001) {
      newStatus = 'Payée';
    } else {
      newStatus = 'Partiellement Payée';
    }

    await ctx.execute(
      'UPDATE factures SET statut = :stat WHERE id = :id',
      {'id': invoiceId, 'stat': newStatus}
    );
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

  static Future<void> approveQuote(int id, {String? callerId, String? callerRole}) async {
    final quote = await _repository.getQuoteById(id);
    if (quote == null) throw Exception('Quote not found.');
    
    // P0 FIX: Prevent re-approving or illegal state transitions
    if (quote.statut == 'Accepté' || quote.statut == 'Approved') {
       throw Exception('Quote is already approved.');
    }

    // RBAC & Ownership:
    // 1. Admin/Comptable/Manager can approve anything.
    // 2. Client role can ONLY approve if it belongs to them.
    if (callerRole != 'Admin' && callerRole != 'Comptable' && callerRole != 'Manager') {
      if (callerId == null) throw Exception('Unauthorized.');
      
      final client = await ClientService.getClientByUserId(callerId);
      if (client == null || client['id'] == null || client['id'].toString() != quote.clientId.toString()) {
        throw Exception('Access denied: You do not own this quote.');
      }
    }

    await _repository.updateQuoteStatus(id, 'Accepté');
  }

  static Future<void> rejectQuote(int id) async {
    await _repository.updateQuoteStatus(id, 'Refusé');
  }

  static Future<void> deleteQuote(int id) async {
    await _repository.deleteQuote(id);
  }
}
