import '../../shared/database/connection.dart';
import '../../shared/domain/credit_score_calculator.dart';

/// Client credit scoring from real payment history (replaces hardcoded stub).
class CreditScoreService {
  static final _db = DBConnection.getConnection();

  static Future<Map<String, dynamic>> calculateClientCreditScore(int id) async {
    final row = await _clientMetrics(id);
    if (row == null) {
      return {
        'score': 0,
        'rating': 'Unknown',
        'lastUpdatedAt': DateTime.now().toUtc().toIso8601String(),
      };
    }
    return _scoreFromMetrics(row);
  }

  static Future<Map<String, dynamic>> getAllClientsWithCreditScores() async {
    final result = await _db.execute('''
      SELECT c.id AS client_id, c.nom, c.raison_sociale, COALESCE(c.solde_du, 0) AS solde_du
      FROM clients c
      ORDER BY c.nom
    ''');
    final clients = <Map<String, dynamic>>[];
    var totalScore = 0.0;
    var count = 0;

    for (final row in result.rows) {
      final m = row.assoc();
      final id = int.tryParse(m['client_id']?.toString() ?? '') ?? 0;
      if (id == 0) continue;
      final metrics = await _clientMetrics(id);
      if (metrics == null) continue;
      final scored = _scoreFromMetrics(metrics);
      clients.add({
        'client_id': id,
        'name': m['raison_sociale'] ?? m['nom'],
        ...scored,
      });
      totalScore += (scored['score'] as num).toDouble();
      count++;
    }

    return {
      'clients': clients,
      'summary': {
        'averageScore': count > 0 ? (totalScore / count).round() : 0,
        'count': count,
      },
    };
  }

  static Future<Map<String, dynamic>> getProjectPaymentHistory(int clientId) async {
    final result = await _db.execute('''
      SELECT
        f.id AS invoice_id,
        f.numero_facture,
        f.montant_ttc,
        f.date_emission,
        f.date_echeance,
        f.statut,
        COALESCE(SUM(p.montant), 0) AS total_paid,
        MIN(p.date_paiement) AS first_payment_date
      FROM factures f
      LEFT JOIN paiements p ON p.facture_id = f.id
      WHERE f.client_id = :cid
      GROUP BY f.id
      ORDER BY f.date_emission DESC
      LIMIT 50
    ''', {'cid': clientId});

    final history = result.rows.map((row) {
      final m = row.assoc();
      return {
        'invoice_id': m['invoice_id'],
        'numero_facture': m['numero_facture'],
        'montant_ttc': m['montant_ttc'],
        'statut': m['statut'],
        'total_paid': m['total_paid'],
        'first_payment_date': m['first_payment_date']?.toString(),
      };
    }).toList();

    return {'clientId': clientId, 'history': history};
  }

  static Future<Map<String, dynamic>?> _clientMetrics(int clientId) async {
    final result = await _db.execute('''
      SELECT
        c.id,
        c.nom,
        c.raison_sociale,
        COALESCE(c.solde_du, 0) AS solde_du,
        COUNT(f.id) AS invoice_count,
        SUM(CASE WHEN f.statut = 'En retard' THEN 1 ELSE 0 END) AS late_count,
        AVG(
          CASE
            WHEN pay.first_payment IS NOT NULL
            THEN GREATEST(0, DATEDIFF(pay.first_payment, f.date_echeance))
          END
        ) AS avg_delay_days
      FROM clients c
      LEFT JOIN factures f ON f.client_id = c.id
        AND f.statut NOT IN ('Brouillon', 'Annulée')
      LEFT JOIN (
        SELECT facture_id, MIN(date_paiement) AS first_payment
        FROM paiements GROUP BY facture_id
      ) pay ON pay.facture_id = f.id
      WHERE c.id = :cid
      GROUP BY c.id, c.nom, c.raison_sociale, c.solde_du
    ''', {'cid': clientId});

    if (result.rows.isEmpty) return null;
    return result.rows.first.assoc();
  }

  static Map<String, dynamic> _scoreFromMetrics(Map<String, dynamic> m) {
    return {
      ...CreditScoreCalculator.scoreFromMetrics(m),
      'lastUpdatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
