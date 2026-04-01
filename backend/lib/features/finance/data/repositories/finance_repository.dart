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

    final billed = double.tryParse(billedRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final paid = double.tryParse(paidRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final compExp = double.tryParse(compExpRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final projExp = double.tryParse(projExpRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    
    final statusDistribution = statusRes.rows.map((row) => row.assoc()).toList();

    return {
      'total_billed': billed,
      'total_paid': paid,
      'outstanding': billed - paid,
      'total_expenses': compExp + projExp,
      'company_expenses': compExp,
      'project_expenses': projExp,
      'net_profit': paid - (compExp + projExp),
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
      INSERT INTO factures (projet_id, client_id, numero_facture, montant_ht, tva, montant_ttc, date_emission, date_echeance, statut)
      VALUES (:pid, :cid, :num, :ht, :tva, :ttc, :em, :ec, :stat)
    ''', {
      'pid': data['projet_id'],
      'cid': data['client_id'],
      'num': data['numero_facture'],
      'ht': data['montant_ht'],
      'tva': data['tva'],
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
}
