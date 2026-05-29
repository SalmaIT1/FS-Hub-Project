import '../../../../shared/database/connection.dart';
import '../../domain/repositories/finance_repository_port.dart';
import '../models/finance_model.dart';

class FinanceRepository implements FinanceRepositoryPort {
  final _db = DBConnection.getConnection();

  Future<Map<String, dynamic>> getFinanceSummary() async {
    // Highly Optimized: Run all summary counters in parallel to minimize DB round-trip latency
    final futures = [
      _db.execute('SELECT SUM(montant_ttc) as total FROM factures'),
      _db.execute('SELECT SUM(montant) as total FROM paiements'),
      _db.execute('SELECT statut, COUNT(*) as count, SUM(montant_ttc) as amount FROM factures GROUP BY statut'),
      _db.execute("SELECT SUM(montant) as total FROM depenses_entreprise WHERE status = 'approved_finance'"),
      _db.execute("SELECT SUM(montant) as total FROM depenses_projets WHERE status = 'approved_finance'"),
      _db.execute("SELECT SUM(net_salary) as total FROM salaries"),
      _db.execute("SELECT SUM(amount) as total FROM bonuses"),
    ];

    final results = await Future.wait(futures);

    final billedRes = results[0];
    final paidRes = results[1];
    final statusRes = results[2];
    final compExpRes = results[3];
    final projExpRes = results[4];
    final salariesRes = results[5];
    final bonusesRes = results[6];

    final billed = double.tryParse(billedRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final paid = double.tryParse(paidRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final compExp = double.tryParse(compExpRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final projExp = double.tryParse(projExpRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final fullPayrollSalaries = double.tryParse(salariesRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final manualBonuses = double.tryParse(bonusesRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final payrollExp = fullPayrollSalaries + manualBonuses;
    
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

  Future<Map<String, dynamic>> getClientFinanceSummary(int clientId) async {
    final futures = [
      _db.execute('SELECT SUM(montant_ttc) as total FROM factures WHERE client_id = :cid', {'cid': clientId}),
      _db.execute('SELECT SUM(montant) as total FROM paiements WHERE client_id = :cid', {'cid': clientId}),
    ];

    final results = await Future.wait(futures);
    final billedRes = results[0];
    final paidRes = results[1];

    final billed = double.tryParse(billedRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
    final paid = double.tryParse(paidRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;

    return {
      'total_billed': billed,
      'total_paid': paid,
      'outstanding': billed - paid,
    };
  }

  Future<List<InvoiceModel>> getAllInvoices({String? before, int limit = 50}) async {
    limit = limit > 200 ? 200 : limit;
    String query = '''
      SELECT f.*, p.nom as project_nom 
      FROM factures f
      LEFT JOIN projets p ON f.projet_id = p.id
    ''';
    Map<String, dynamic> params = {};
    if (before != null && before.isNotEmpty) {
      query += ' WHERE f.date_emission < :before';
      params['before'] = before;
    }
    query += ' ORDER BY f.date_emission DESC LIMIT :limit';
    params['limit'] = limit;
    
    final result = await _db.execute(query, params);
    return result.rows.map<InvoiceModel>((row) => InvoiceModel.fromMap(row.assoc())).toList();
  }

  Future<List<InvoiceModel>> getInvoicesByProject(int projectId) async {
    final result = await _db.execute('SELECT * FROM factures WHERE projet_id = :pid', {'pid': projectId});
    return result.rows.map<InvoiceModel>((row) => InvoiceModel.fromMap(row.assoc())).toList();
  }

  Future<List<InvoiceModel>> getInvoicesByClient(int clientId) async {
    final result = await _db.execute('SELECT * FROM factures WHERE client_id = :cid ORDER BY date_emission DESC', {'cid': clientId});
    return result.rows.map<InvoiceModel>((row) => InvoiceModel.fromMap(row.assoc())).toList();
  }

  Future<InvoiceModel?> getInvoiceById(int id) async {
    final result = await _db.execute('SELECT * FROM factures WHERE id = :id', {'id': id});
    if (result.rows.isEmpty) return null;
    return InvoiceModel.fromMap(result.rows.first.assoc());
  }

  Future<String> _getSetting(String key, String defaultValue) async {
    try {
      final res = await _db.execute(
        'SELECT setting_value FROM system_settings WHERE setting_key = :k',
        {'k': key},
      );
      if (res.rows.isEmpty) return defaultValue;
      return res.rows.first.colByName('setting_value')?.toString() ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> createInvoice(Map<String, dynamic> data) async {
    await _db.transaction((tx) async {
      // P1 FIX: Idempotency Guard - Avoid duplicate invoice numbers
      final numFact = data['numero_facture'];
      final existing = await tx.execute(
        'SELECT id FROM factures WHERE numero_facture = :num FOR UPDATE',
        {'num': numFact},
      );
      if (existing.rows.isNotEmpty) {
        throw Exception('Une facture avec le numéro $numFact existe déjà.');
      }

      final devisId = data['devis_id'];
      if (devisId != null) {
        final devRes = await tx.execute('SELECT statut FROM devis WHERE id = :id FOR UPDATE', {'id': devisId});
        if (devRes.rows.isNotEmpty) {
           final status = devRes.rows.first.assoc()['statut']?.toString() ?? '';
           const approvedStates = ['Approuve', 'Approuvé', 'Accepté', 'Accepted'];
           if (!approvedStates.contains(status)) {
             throw Exception('Impossible de créer la facture : le devis associé n\'est pas approuvé (Statut actuel: $status)');
           }
        } else {
           throw Exception('Devis associé introuvable.');
        }
      }

      // P2-02 FIX: Fetch timbre from database settings instead of hardcoding.
      final timbreSetting = await _getSetting('finance_timbre_fiscal', '1.0');
      final timbreValue = double.tryParse(timbreSetting) ?? 1.0;

      await tx.execute('''
        INSERT INTO factures (projet_id, client_id, numero_facture, type, montant_ht, tva, timbre, montant_ttc, date_emission, date_echeance, statut, devis_id)
        VALUES (:pid, :cid, :num, :type, :ht, :tva, :timbre, :ttc, :em, :ec, :stat, :devisId)
      ''', {
        'pid': data['projet_id'],
        'cid': data['client_id'],
        'num': numFact,
        'type': data['type'] ?? 'INVOICE',
        'ht': data['montant_ht'],
        'tva': data['tva'],
        'timbre': data['timbre'] ?? (data['type'] == 'DELIVERY_NOTE' ? 0.0 : timbreValue),
        'ttc': data['montant_ttc'],
        'em': data['date_emission'],
        'ec': data['date_echeance'],
        'stat': data['statut'] ?? 'Brouillon',
        'devisId': devisId,
      });
    });
  }

  Future<void> updateInvoice(int id, Map<String, dynamic> data) async {
    await _db.transaction((tx) async {
      // P0 FIX: Guard against updating invoices that are already paid/sent.
      final invRes = await tx.execute(
        'SELECT statut FROM factures WHERE id = :id FOR UPDATE', {'id': id},
      );
      if (invRes.rows.isNotEmpty) {
        final statut = invRes.rows.first.colByName('statut')?.toString() ?? '';
        const blocked = ['Envoyée', 'Payée', 'Partiellement payée'];
        if (blocked.contains(statut)) {
          throw Exception(
            'Cannot modify invoice with status "$statut". '
          );
        }
      }

      await tx.execute('''
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
    });
  }

  Future<void> deleteInvoice(int id) async {
    // P1-1 FIX: Run status check + delete inside a single transaction with
    // a FOR UPDATE lock to eliminate the concurrent approve/delete race
    // condition that could orphan payment records.
    await _db.transaction<void>((tx) async {
      final invRes = await tx.execute(
        'SELECT statut FROM factures WHERE id = :id FOR UPDATE', {'id': id},
      );
      if (invRes.rows.isEmpty) return; // Already gone — no-op.
      final statut = invRes.rows.first.colByName('statut')?.toString() ?? '';
      
      // P2-02 FIX: Resolve friction - Allow deleting 'Sent' invoices if unpaid.
      // We block deletion ONLY if it has actual money recorded.
      if (statut == 'Payée' || statut == 'Partiellement payée') {
        throw Exception(
          'Cannot delete invoice with status "$statut". '
          'Please delete associated payments first.',
        );
      }
      
      // Double check payments count just in case status is out of sync
      final payRes = await tx.execute('SELECT COUNT(*) as cnt FROM paiements WHERE facture_id = :id', {'id': id});
      final payCount = int.tryParse(payRes.rows.first.colByName('cnt')?.toString() ?? '0') ?? 0;
      if (payCount > 0) {
        throw Exception('Cannot delete invoice: it already has associated payments.');
      }

      await tx.execute('DELETE FROM factures WHERE id = :id', {'id': id});
    });
  }

  Future<List<PaymentModel>> getPaymentsByInvoice(int invoiceId) async {
    final result = await _db.execute('SELECT * FROM paiements WHERE facture_id = :fid', {'fid': invoiceId});
    return result.rows.map<PaymentModel>((row) => PaymentModel.fromMap(row.assoc())).toList();
  }

  Future<PaymentModel?> getPaymentById(int id) async {
    final result = await _db.execute('SELECT * FROM paiements WHERE id = :id', {'id': id});
    if (result.rows.isEmpty) return null;
    return PaymentModel.fromMap(result.rows.first.assoc());
  }

  Future<void> createPayment(Map<String, dynamic> data) async {
    await _db.transaction<void>((tx) async {
      // Fetch client_id from the facture to populate paiements.client_id
      final invRes = await tx.execute('SELECT client_id FROM factures WHERE id = :fid', {'fid': data['facture_id']});
      final clientId = invRes.rows.isNotEmpty ? invRes.rows.first.colByName('client_id') : null;

      // Idempotency check: Ensure the same payment reference isn't duplicated
      final ref = data['reference_transaction'];
      if (ref != null && ref.toString().isNotEmpty) {
        final existing = await tx.execute('SELECT id FROM paiements WHERE reference_transaction = :ref FOR UPDATE', {'ref': ref});
        if (existing.rows.isNotEmpty) {
           throw Exception('Idempotency error: Payment with this reference already exists');
        }
      }
      
      await tx.execute('''
        INSERT INTO paiements (facture_id, client_id, montant, mode, date_paiement, reference_transaction)
        VALUES (:fid, :cid, :mnt, :mode, :date, :ref)
      ''', {
        'fid': data['facture_id'],
        'cid': clientId,
        'mnt': data['montant'],
        'mode': data['mode'],
        'date': data['date_paiement'],
        'ref': ref,
      });

      // DB Triggers handle the recalucation and state merging (P1.1 fix)
    });
  }

  Future<void> deletePayment(int id) async {
    await _db.transaction<void>((tx) async {
      // 1. Lock and read the payment
      final payRes = await tx.execute(
        'SELECT facture_id FROM paiements WHERE id = :id FOR UPDATE',
        {'id': id},
      );
      if (payRes.rows.isEmpty) return; // Payment not found — no-op.

      // 2. Delete the payment.
      await tx.execute('DELETE FROM paiements WHERE id = :id', {'id': id});

      // DB Triggers handle the recalucation and state merging (P1.1 fix)
    });
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

  Future<List<QuoteModel>> getQuotesByProject(int projectId) async {
    final result = await _db.execute('''
      SELECT d.* FROM devis d WHERE d.projet_id = :pid
      ORDER BY d.created_at DESC
    ''', {'pid': projectId});
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
    await _db.transaction<void>((tx) async {
      // Idempotency guard: reject duplicates by numero_devis.
      // Protects against network retries creating multiple identical quotes.
      final num = data['numero_devis']?.toString() ?? '';
      if (num.isNotEmpty) {
        final existing = await tx.execute(
          'SELECT id FROM devis WHERE numero_devis = :num FOR UPDATE',
          {'num': num},
        );
        if (existing.rows.isNotEmpty) {
          throw Exception(
            'Idempotency error: A quote with numero_devis "$num" already exists.',
          );
        }
      }
      await tx.execute('''
        INSERT INTO devis (projet_id, client_id, numero_devis, montant_ht, tva, montant_ttc, date_emission, date_validite, statut)
        VALUES (:pid, :cid, :num, :ht, :tva, :ttc, :em, :val, :stat)
      ''', {
        'pid': data['projet_id'],
        'cid': data['client_id'],
        'num': num,
        'ht': data['montant_ht'],
        'tva': data['tva'],
        'ttc': data['montant_ttc'],
        'em': data['date_emission'],
        'val': data['date_validite'],
        'stat': data['statut'] ?? 'Brouillon',
      });
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
