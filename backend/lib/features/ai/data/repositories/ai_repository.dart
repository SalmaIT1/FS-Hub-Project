import '../../../../shared/database/connection.dart';

class AIRepository {
  final _db = DBConnection.getConnection();

  /// Active projects with ML-ready features for delay prediction.
  Future<List<Map<String, dynamic>>> getProjectsForPrediction() async {
    try {
      final result = await _db.execute('''
        SELECT
          p.id,
          p.nom,
          p.statut,
          p.priorite,
          p.budget,
          p.cout_estime,
          p.date_fin_prevue,
          p.client_id,
          (
            SELECT COUNT(*)
            FROM taches t
            INNER JOIN sprints s ON t.sprint_id = s.id
            WHERE s.projet_id = p.id
          ) AS total_tasks,
          (
            SELECT COUNT(*)
            FROM taches t
            INNER JOIN sprints s ON t.sprint_id = s.id
            WHERE s.projet_id = p.id AND t.statut = 'Done'
          ) AS completed_tasks,
          (
            SELECT COUNT(*)
            FROM taches t
            INNER JOIN sprints s ON t.sprint_id = s.id
            WHERE s.projet_id = p.id
              AND t.statut != 'Done'
              AND t.updated_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
          ) AS delayed_tasks,
          DATEDIFF(p.date_fin_prevue, CURDATE()) AS days_remaining,
          (
            SELECT COUNT(DISTINCT pm.employee_id)
            FROM projet_membres pm
            WHERE pm.projet_id = p.id
          ) AS team_size,
          COALESCE((
            SELECT AVG(
              CASE
                WHEN a.status IN ('present', 'remote') THEN 1.0
                WHEN a.status = 'half_day' THEN 0.5
                ELSE 0.0
              END
            )
            FROM projet_membres pm
            INNER JOIN attendance a ON a.employee_id = pm.employee_id
              AND a.attendance_date >= DATE_SUB(CURDATE(), INTERVAL 14 DAY)
            WHERE pm.projet_id = p.id
          ), 0.85) AS team_availability,
          COALESCE(c.solde_du, 0) AS client_outstanding,
          (
            SELECT AVG(
              CASE
                WHEN t.estimation_heures > 0
                THEN t.heures_reelles / t.estimation_heures
                ELSE 1.0
              END
            )
            FROM taches t
            INNER JOIN sprints s ON t.sprint_id = s.id
            WHERE s.projet_id = p.id AND t.statut = 'Done'
          ) AS avg_estimate_accuracy,
          (
            SELECT COUNT(*)
            FROM sprints s
            WHERE s.projet_id = p.id
          ) AS sprint_count
        FROM projets p
        LEFT JOIN clients c ON p.client_id = c.id
        WHERE p.statut IN ('En cours', 'A venir')
           OR p.statut LIKE 'En cours%'
      ''');

      final projects = result.rows.map((row) => row.assoc()).toList();
      return projects;
    } catch (e) {
      print('AI REPOSITORY ERROR (projects): $e');
      return [];
    }
  }

  /// Per-client payment aggregates for risk scoring.
  Future<List<Map<String, dynamic>>> getClientPaymentAggregates() async {
    try {
      final result = await _db.execute('''
        SELECT
          c.id AS client_id,
          c.nom,
          c.raison_sociale,
          COALESCE(c.solde_du, 0) AS solde_du,
          COUNT(f.id) AS invoice_count_12m,
          SUM(f.montant_ttc) AS total_invoiced_12m,
          SUM(COALESCE(pay.paid_sum, 0)) AS total_paid_12m,
          SUM(CASE WHEN f.statut = 'En retard' THEN 1 ELSE 0 END) AS late_invoice_count,
          AVG(
            CASE
              WHEN pay.first_payment_date IS NOT NULL
              THEN GREATEST(0, DATEDIFF(pay.first_payment_date, f.date_echeance))
              ELSE NULL
            END
          ) AS avg_payment_delay_days,
          SUM(CASE WHEN f.statut IN ('Payée', 'Partiellement payée') THEN 1 ELSE 0 END)
            / NULLIF(COUNT(f.id), 0) AS on_time_ratio
        FROM clients c
        LEFT JOIN factures f ON f.client_id = c.id
          AND f.date_emission >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
          AND f.statut NOT IN ('Brouillon', 'Annulée')
        LEFT JOIN (
          SELECT
            facture_id,
            SUM(montant) AS paid_sum,
            MIN(date_paiement) AS first_payment_date
          FROM paiements
          GROUP BY facture_id
        ) pay ON pay.facture_id = f.id
        GROUP BY c.id, c.nom, c.raison_sociale, c.solde_du
        HAVING invoice_count_12m > 0
        ORDER BY late_invoice_count DESC, solde_du DESC
      ''');
      return result.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      print('AI REPOSITORY ERROR (clients): $e');
      return [];
    }
  }

  /// Open invoices for payment probability prediction.
  Future<List<Map<String, dynamic>>> getOpenInvoicesForPrediction() async {
    try {
      final result = await _db.execute('''
        SELECT
          f.id AS invoice_id,
          f.client_id,
          f.projet_id,
          f.numero_facture,
          f.montant_ttc,
          f.date_emission,
          f.date_echeance,
          f.statut,
          DATEDIFF(f.date_echeance, CURDATE()) AS days_until_due,
          COALESCE(c.solde_du, 0) AS client_outstanding,
          c.nom AS client_nom,
          c.raison_sociale,
          COALESCE((
            SELECT AVG(GREATEST(0, DATEDIFF(p.date_paiement, f2.date_echeance)))
            FROM factures f2
            INNER JOIN paiements p ON p.facture_id = f2.id
            WHERE f2.client_id = f.client_id
              AND f2.date_emission >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
          ), 0) AS client_avg_delay_days,
          (
            SELECT COUNT(*)
            FROM factures f3
            WHERE f3.client_id = f.client_id
              AND f3.statut = 'En retard'
          ) AS client_late_invoices
        FROM factures f
        INNER JOIN clients c ON c.id = f.client_id
        WHERE f.statut IN ('Envoyée', 'Partiellement payée', 'En retard')
        ORDER BY f.date_echeance ASC
        LIMIT 200
      ''');
      return result.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      print('AI REPOSITORY ERROR (invoices): $e');
      return [];
    }
  }

  /// Employee productivity features (last 30 days).
  Future<List<Map<String, dynamic>>> getEmployeeProductivityFeatures() async {
    try {
      final result = await _db.execute('''
        SELECT
          e.id AS employee_id,
          CONCAT(e.prenom, ' ', e.nom) AS employee_name,
          COUNT(DISTINCT a.attendance_date) AS total_days,
          SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) AS absent_days,
          SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) AS late_days,
          (
            SELECT COUNT(*)
            FROM taches t
            WHERE t.employee_id = e.id
              AND t.updated_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
          ) AS assigned_tasks_30d,
          (
            SELECT COUNT(*)
            FROM taches t
            WHERE t.employee_id = e.id
              AND t.statut = 'Done'
              AND t.updated_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
          ) AS completed_tasks_30d,
          (
            SELECT COUNT(*)
            FROM projet_membres pm
            INNER JOIN projets p ON p.id = pm.projet_id
            WHERE pm.employee_id = e.id
              AND p.statut IN ('En cours', 'A venir')
          ) AS active_projects
        FROM employees e
        LEFT JOIN attendance a ON a.employee_id = e.id
          AND a.attendance_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        WHERE e.is_active = 1 OR e.is_active IS NULL
        GROUP BY e.id, e.prenom, e.nom
      ''');
      return result.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      print('AI REPOSITORY ERROR (employees): $e');
      return [];
    }
  }

  /// Company expenses for anomaly detection batch.
  Future<List<Map<String, dynamic>>> getExpensesForAnomalyScan() async {
    try {
      final result = await _db.execute('''
        SELECT
          id,
          'company' AS expense_type,
          montant,
          category_id,
          description,
          status,
          created_by,
          created_at
        FROM depenses_entreprise
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)
        UNION ALL
        SELECT
          id,
          'project' AS expense_type,
          montant,
          category_id,
          description,
          status,
          created_by,
          created_at
        FROM depenses_projets
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)
        LIMIT 500
      ''');
      return result.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      print('AI REPOSITORY ERROR (expenses): $e');
      return [];
    }
  }

  /// Dashboard KPI aggregates.
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final projects = await getProjectsForPrediction();
    final clients = await getClientPaymentAggregates();
    final invoices = await getOpenInvoicesForPrediction();

    final billedRes = await _db.execute(
      "SELECT COALESCE(SUM(montant_ttc), 0) AS total FROM factures WHERE statut NOT IN ('Brouillon', 'Annulée')",
    );
    final paidRes = await _db.execute('SELECT COALESCE(SUM(montant), 0) AS total FROM paiements');
    final expenseRes = await _db.execute(
      "SELECT COALESCE(SUM(montant), 0) AS total FROM depenses_entreprise WHERE status = 'approved_finance'",
    );
    final overdueRes = await _db.execute(
      "SELECT COUNT(*) AS cnt FROM factures WHERE statut = 'En retard'",
    );

    return {
      'active_projects': projects.length,
      'clients_analyzed': clients.length,
      'open_invoices': invoices.length,
      'total_billed': billedRes.rows.first.assoc()['total'] ?? 0,
      'total_paid': paidRes.rows.first.assoc()['total'] ?? 0,
      'total_expenses': expenseRes.rows.first.assoc()['total'] ?? 0,
      'overdue_invoices': overdueRes.rows.first.assoc()['cnt'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> getCompanyFinancialContext() async {
    return getDashboardSummary();
  }
}
