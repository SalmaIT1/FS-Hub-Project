import '../../../../shared/database/connection.dart';
import '../models/finance_model.dart';

class FinanceRepository {
  final _db = DBConnection.getConnection();

  Future<Map<String, dynamic>> getFinanceSummary() async {
    final billedRes = await _db.execute('SELECT SUM(montant_ttc) as total FROM factures');
    final paidRes = await _db.execute('SELECT SUM(montant) as total FROM paiements');
    final statusRes = await _db.execute('SELECT statut, COUNT(*) as count, SUM(montant_ttc) as amount FROM factures GROUP BY statut');
    
    // Expenses
    final compExpRes = await _db.execute("SELECT SUM(montant) as total FROM depenses_entreprise WHERE status = 'approved_finance'");
    final projExpRes = await _db.execute("SELECT SUM(montant) as total FROM depenses_projets WHERE status = 'approved_finance'");
    
    // Payroll: All salaries (Base parts) + All bonuses
    // We subtract bonus_amount from net_salary to avoid double counting when we add bonuses separately
    final salariesRes = await _db.execute("SELECT SUM(net_salary - bonus_amount) as total FROM salaries");
    final bonusesRes = await _db.execute("SELECT SUM(amount) as total FROM bonuses");
    
    // Paid payroll for cash-flow view if needed
    final paidSalariesRes = await _db.execute("SELECT SUM(net_salary) as total FROM salaries WHERE payment_status = 'paid'");

    final billed = double.tryParse(billedRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final paid = double.tryParse(paidRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final compExp = double.tryParse(compExpRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final projExp = double.tryParse(projExpRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final basePayrollExp = double.tryParse(salariesRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final totalBonusesExp = double.tryParse(bonusesRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final payrollExp = basePayrollExp + totalBonusesExp;
    
    final totalExpenses = compExp + projExp + payrollExp;
    final statusDistribution = statusRes.rows.map((row) => row.assoc()).toList();

    return {
      'total_billed': billed,
      'total_paid': paid,
      'outstanding': billed - paid,
      'total_expenses': totalExpenses,
      'company_expenses': compExp,
      'project_expenses': projExp,
      'payroll_expenses': payrollExp,
      'net_profit': paid - totalExpenses,
      'status_distribution': statusDistribution,
    };
  }

  Future<List<InvoiceModel>> getAllInvoices() async {
    final result = await _db.execute('''
      SELECT f.*, p.nom as project_nom 
      FROM factures f
      LEFT JOIN projets p ON f.projet_id = p.id
      ORDER BY f.date_emission DESC
    ''');
    return result.rows.map<InvoiceModel>((row) => InvoiceModel.fromMap(row.assoc())).toList();
  }

  Future<List<InvoiceModel>> getInvoicesByProject(int projectId) async {
    final result = await _db.execute('SELECT * FROM factures WHERE projet_id = :pid', {'pid': projectId});
    return result.rows.map<InvoiceModel>((row) => InvoiceModel.fromMap(row.assoc())).toList();
  }

  Future<InvoiceModel?> getInvoiceById(int id) async {
    final result = await _db.execute('SELECT * FROM factures WHERE id = :id', {'id': id});
    if (result.rows.isEmpty) return null;
    return InvoiceModel.fromMap(result.rows.first.assoc());
  }

  Future<void> createInvoice(Map<String, dynamic> data) async {
    await _db.execute('''
      INSERT INTO factures (projet_id, client_id, numero_facture, type, montant_ht, tva, timbre, montant_ttc, date_emission, date_echeance, statut)
      VALUES (:pid, :cid, :num, :type, :ht, :tva, :timbre, :ttc, :em, :ec, :stat)
    ''', {
      'pid': data['projet_id'],
      'cid': data['client_id'],
      'num': data['numero_facture'],
      'type': data['type'] ?? 'INVOICE',
      'ht': data['montant_ht'],
      'tva': data['tva'],
      'timbre': data['timbre'] ?? (data['type'] == 'DELIVERY_NOTE' ? 0.0 : 1.0),
      'ttc': data['montant_ttc'],
      'em': data['date_emission'],
      'ec': data['date_echeance'],
      'stat': data['statut'] ?? 'Brouillon',
    });
  }

  Future<void> updateInvoice(int id, Map<String, dynamic> data) async {
    await _db.execute('''
      UPDATE factures SET 
        numero_facture = :num, montant_ht = :ht, tva = :tva, 
        montant_ttc = :ttc, date_emission = :em, date_echeance = :ec, statut = :stat
      WHERE id = :id
    ''', {
      'id': id,
      'num': data['numero_facture'],
      'ht': data['montant_ht'],
      'tva': data['tva'],
      'ttc': data['montant_ttc'],
      'em': data['date_emission'],
      'ec': data['date_echeance'],
      'stat': data['statut'],
    });
  }

  Future<void> deleteInvoice(int id) async {
    await _db.execute('DELETE FROM factures WHERE id = :id', {'id': id});
  }

  Future<List<PaymentModel>> getPaymentsByInvoice(int invoiceId) async {
    final result = await _db.execute('SELECT * FROM paiements WHERE facture_id = :fid', {'fid': invoiceId});
    return result.rows.map<PaymentModel>((row) => PaymentModel.fromMap(row.assoc())).toList();
  }

  Future<void> createPayment(Map<String, dynamic> data) async {
    await _db.execute('''
      INSERT INTO paiements (facture_id, montant, mode, date_paiement, reference_transaction)
      VALUES (:fid, :mnt, :mode, :date, :ref)
    ''', {
      'fid': data['facture_id'],
      'mnt': data['montant'],
      'mode': data['mode'],
      'date': data['date_paiement'],
      'ref': data['reference_transaction'],
    });
  }

  Future<void> deletePayment(int id) async {
    await _db.execute('DELETE FROM paiements WHERE id = :id', {'id': id});
  }

  // ---- Quotes (Devis) Methods ----
  
  Future<List<QuoteModel>> getAllQuotes() async {
    final result = await _db.execute('''
      SELECT d.*, p.nom as project_nom, c.nom as client_nom, c.raison_sociale
      FROM devis d
      LEFT JOIN projets p ON d.projet_id = p.id
      LEFT JOIN clients c ON d.client_id = c.id
      ORDER BY d.date_emission DESC
    ''');
    
    return result.rows.map<QuoteModel>((row) {
      final map = row.assoc();
      final clientNom = map['raison_sociale']?.toString() ?? map['client_nom']?.toString();
      map['client_nom'] = clientNom;
      return QuoteModel.fromMap(map);
    }).toList();
  }

  Future<List<QuoteModel>> getQuotesByClient(int clientId) async {
    final result = await _db.execute('''
      SELECT d.*, p.nom as project_nom 
      FROM devis d
      LEFT JOIN projets p ON d.projet_id = p.id
      WHERE d.client_id = :cid
      ORDER BY d.created_at DESC
    ''', {'cid': clientId});
    return result.rows.map<QuoteModel>((row) => QuoteModel.fromMap(row.assoc())).toList();
  }

  Future<QuoteModel?> getQuoteById(int id) async {
    final result = await _db.execute('''
      SELECT d.*, p.nom as project_nom, c.nom as client_nom, c.raison_sociale
      FROM devis d
      LEFT JOIN projets p ON d.projet_id = p.id
      LEFT JOIN clients c ON d.client_id = c.id
      WHERE d.id = :id
    ''', {'id': id});
    if (result.rows.isEmpty) return null;
    
    final map = result.rows.first.assoc();
    final clientNom = map['raison_sociale']?.toString() ?? map['client_nom']?.toString();
    map['client_nom'] = clientNom;
    return QuoteModel.fromMap(map);
  }

  Future<void> createQuote(Map<String, dynamic> data) async {
    await _db.execute('''
      INSERT INTO devis (projet_id, client_id, numero_devis, montant_ht, tva, montant_ttc, date_emission, date_validite, statut)
      VALUES (:pid, :cid, :num, :ht, :tva, :ttc, :em, :val, :stat)
    ''', {
      'pid': data['projet_id'],
      'cid': data['client_id'],
      'num': data['numero_devis'],
      'ht': data['montant_ht'],
      'tva': data['tva'],
      'ttc': data['montant_ttc'],
      'em': data['date_emission'],
      'val': data['date_validite'],
      'stat': data['statut'] ?? 'Brouillon',
    });
  }

  Future<void> updateQuote(int id, Map<String, dynamic> data) async {
    await _db.execute('''
      UPDATE devis SET 
        numero_devis = :num, montant_ht = :ht, tva = :tva, 
        montant_ttc = :ttc, date_emission = :em, date_validite = :val, statut = :stat
      WHERE id = :id
    ''', {
      'id': id,
      'num': data['numero_devis'],
      'ht': data['montant_ht'],
      'tva': data['tva'],
      'ttc': data['montant_ttc'],
      'em': data['date_emission'],
      'val': data['date_validite'],
      'stat': data['statut'],
    });
  }

  Future<void> updateQuoteStatus(int id, String status) async {
    await _db.execute('UPDATE devis SET statut = :status WHERE id = :id', {
      'id': id,
      'status': status,
    });
  }

  Future<void> deleteQuote(int id) async {
    await _db.execute('DELETE FROM devis WHERE id = :id', {'id': id});
  }
}
