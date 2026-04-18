import '../../../../shared/database/connection.dart';

class AIRepository {
  final _db = DBConnection.getConnection();

  /// Fetches all active projects with their task completion status for delay prediction.
  Future<List<Map<String, dynamic>>> getProjectsForPrediction() async {
    try {
      final result = await _db.execute('''
        SELECT 
          p.id, p.nom, p.statut,
          (
            SELECT COUNT(*) 
            FROM taches t 
            INNER JOIN sprints s ON t.sprint_id = s.id 
            WHERE s.projet_id = p.id
          ) as total_tasks,
          (
            SELECT COUNT(*) 
            FROM taches t 
            INNER JOIN sprints s ON t.sprint_id = s.id 
            WHERE s.projet_id = p.id AND t.statut = 'Done'
          ) as completed_tasks
        FROM projets p
        WHERE p.statut LIKE 'En cours%'
      ''');
      
      final projects = result.rows.map((row) => row.assoc()).toList();
      print('AI DEBUG: Found ${projects.length} projects for analysis.');
      return projects;
    } catch (e) {
      print('AI REPOSITORY ERROR: $e');
      return [];
    }
  }

  /// Fetches client payment history for behavior analysis.
  Future<List<Map<String, dynamic>>> getClientPaymentHistory() async {
    final result = await _db.execute('''
      SELECT 
        c.id as client_id,
        c.nom,
        c.raison_sociale,
        f.id as invoice_id,
        f.montant_ttc,
        f.date_emission,
        f.date_echeance,
        f.statut as invoice_status,
        (SELECT SUM(montant) FROM paiements p WHERE p.facture_id = f.id) as total_paid,
        (SELECT MAX(date_paiement) FROM paiements p WHERE p.facture_id = f.id) as last_payment_date
      FROM clients c
      INNER JOIN factures f ON c.id = f.client_id
      ORDER BY c.id, f.date_emission DESC
    ''');
    return result.rows.map((row) => row.assoc()).toList();
  }

  /// Fetches general company stats for the intelligent dashboard.
  Future<Map<String, dynamic>> getCompanyFinancialContext() async {
    final billedRes = await _db.execute('SELECT SUM(montant_ttc) as total FROM factures');
    final paidRes = await _db.execute('SELECT SUM(montant) as total FROM paiements');
    final expenseRes = await _db.execute("SELECT SUM(montant) as total FROM depenses_entreprise WHERE status = 'approved_finance'");
    
    return {
      'total_billed': billedRes.rows.first.assoc()['total'] ?? 0,
      'total_paid': paidRes.rows.first.assoc()['total'] ?? 0,
      'total_expenses': expenseRes.rows.first.assoc()['total'] ?? 0,
    };
  }
}
