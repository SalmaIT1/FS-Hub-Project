import 'package:mysql_client/mysql_client.dart';
import '../models/credit_model.dart';
import '../../../../shared/database/connection.dart';

class CreditRepository {
  final _db = DBConnection.getConnection();

  Future<List<CreditModel>> getAllCredits() async {
    try {
      final results = await _db.execute('''
        SELECT c.*, cl.nom as client_name, pj.nom as project_name, inv.numero as invoice_number
        FROM credits c
        LEFT JOIN clients cl ON c.client_id = cl.id
        LEFT JOIN projets pj ON c.projet_id = pj.id
        LEFT JOIN invoices inv ON c.invoice_id = inv.id
        ORDER BY c.date_credit DESC
      ''');
      
      return results.rows.map((row) => CreditModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<CreditModel?> getCreditById(int id) async {
    try {
      final results = await _db.execute('''
        SELECT c.*, cl.nom as client_name, pj.nom as project_name, inv.numero as invoice_number
        FROM credits c
        LEFT JOIN clients cl ON c.client_id = cl.id
        LEFT JOIN projets pj ON c.projet_id = pj.id
        LEFT JOIN invoices inv ON c.invoice_id = inv.id
        WHERE c.id = ?
      ''', {'id': id});
      
      if (results.rows.isEmpty) return null;
      return CreditModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }

  Future<CreditModel> createCredit(CreditModel credit) async {
    try {
      final results = await _db.execute('''
        INSERT INTO credits (type, montant, date_credit, description, client_id, projet_id, invoice_id, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', {
        'type': credit.type,
        'montant': credit.montant,
        'date_credit': credit.dateCredit.toIso8601String().split('T')[0],
        'description': credit.description,
        'client_id': credit.clientId,
        'projet_id': credit.projectId,
        'invoice_id': credit.invoiceId,
        'created_by': credit.createdBy,
      });
      
      final id = results.lastInsertID.toInt();
      return credit.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create credit: $e');
    }
  }

  Future<CreditModel> updateCredit(CreditModel credit) async {
    try {
      await _db.execute('''
        UPDATE credits 
        SET type = ?, montant = ?, date_credit = ?, description = ?, client_id = ?, projet_id = ?, invoice_id = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      ''', {
        'type': credit.type,
        'montant': credit.montant,
        'date_credit': credit.dateCredit.toIso8601String().split('T')[0],
        'description': credit.description,
        'client_id': credit.clientId,
        'projet_id': credit.projectId,
        'invoice_id': credit.invoiceId,
        'id': credit.id,
      });
      
      return credit;
    } catch (e) {
      throw Exception('Failed to update credit: $e');
    }
  }

  Future<bool> deleteCredit(int id) async {
    try {
      final results = await _db.execute('DELETE FROM credits WHERE id = ?', {'id': id});
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<CreditModel>> getProjectCredits(int projectId) async {
    try {
      final results = await _db.execute('''
        SELECT c.*, cl.nom as client_name, inv.numero as invoice_number
        FROM credits c
        LEFT JOIN clients cl ON c.client_id = cl.id
        LEFT JOIN invoices inv ON c.invoice_id = inv.id
        WHERE c.projet_id = ?
        ORDER BY c.date_credit DESC
      ''', {'projectId': projectId});
      
      return results.rows.map((row) => CreditModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<CreditModel>> getClientCredits(int clientId) async {
    try {
      final results = await _db.execute('''
        SELECT c.*, pj.nom as project_name, inv.numero as invoice_number
        FROM credits c
        LEFT JOIN projets pj ON c.projet_id = pj.id
        LEFT JOIN invoices inv ON c.invoice_id = inv.id
        WHERE c.client_id = ?
        ORDER BY c.date_credit DESC
      ''', {'clientId': clientId});
      
      return results.rows.map((row) => CreditModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getCreditSummary() async {
    try {
      final results = await _db.execute('''
        SELECT 
          COUNT(*) as total_credits,
          SUM(montant) as total_amount,
          SUM(CASE WHEN used = 1 THEN montant ELSE 0 END) as used_credits,
          SUM(CASE WHEN used = 0 THEN montant ELSE 0 END) as available_credits
        FROM (
          SELECT *, 
          CASE WHEN invoice_id IS NOT NULL OR projet_id IS NOT NULL THEN 1 ELSE 0 END as used
        ) c
        WHERE c.deleted_at IS NULL
      ''');
      
      if (results.rows.isEmpty) return {};
      
      final row = results.rows.first;
      
      return {
        'total_credits': row['total_credits'],
        'total_amount': row['total_amount'],
        'used_credits': row['used_credits'],
        'available_credits': row['available_credits'],
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getProjectCreditSummary(int projectId) async {
    try {
      final results = await _db.execute('''
        SELECT 
          COUNT(*) as total_credits,
          SUM(montant) as total_amount,
          SUM(CASE WHEN invoice_id IS NOT NULL THEN montant ELSE 0 END) as used_credits,
          SUM(CASE WHEN invoice_id IS NULL AND projet_id IS NOT NULL THEN montant ELSE 0 END) as project_credits
        FROM credits c
        WHERE c.projet_id = ? AND c.deleted_at IS NULL
      ''', {'projectId': projectId});
      
      if (results.rows.isEmpty) return {};
      
      final row = results.rows.first;
      
      return {
        'total_credits': row['total_credits'],
        'total_amount': row['total_amount'],
        'used_credits': row['used_credits'],
        'project_credits': row['project_credits'],
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getClientCreditSummary(int clientId) async {
    try {
      final results = await _db.execute('''
        SELECT 
          COUNT(*) as total_credits,
          SUM(montant) as total_amount,
          SUM(CASE WHEN invoice_id IS NOT NULL THEN montant ELSE 0 END) as used_credits,
          SUM(CASE WHEN invoice_id IS NULL AND client_id IS NOT NULL THEN montant ELSE 0 END) as client_credits
        FROM credits c
        WHERE c.client_id = ? AND c.deleted_at IS NULL
      ''', {'clientId': clientId});
      
      if (results.rows.isEmpty) return {};
      
      final row = results.rows.first;
      
      return {
        'total_credits': row['total_credits'],
        'total_amount': row['total_amount'],
        'used_credits': row['used_credits'],
        'client_credits': row['client_credits'],
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getClientCreditLimit(int clientId) async {
    try {
      final results = await _db.execute('''
        SELECT 
          COALESCE(SUM(montant), 0) as total_credits,
          COALESCE(SUM(CASE WHEN invoice_id IS NULL AND client_id = ? THEN montant ELSE 0 END), 0) as available_credits
        FROM credits c
        WHERE c.client_id = ? AND c.deleted_at IS NULL
      ''', {'clientId': clientId});
      
      if (results.rows.isEmpty) return {};
      
      final row = results.rows.first;
      
      return {
        'total_credits': row['total_credits'],
        'available_credits': row['available_credits'],
        'credit_limit': row['available_credits'],
      };
    } catch (e) {
      return {};
    }
  }

  Future<bool> updateClientCreditLimit(int clientId, double newLimit) async {
    try {
      await _db.execute('''
        UPDATE clients 
        SET credit_limit = ?
        WHERE id = ?
      ''', {'newLimit': newLimit, 'clientId': clientId});
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> applyCreditToProject(int creditId, int projectId, double amount) async {
    try {
      await _db.execute('''
        UPDATE credits 
        SET montant = montant - ?, projet_id = ?
        WHERE id = ? AND (montant - ?) >= 0
      ''', {'amount': amount, 'projectId': projectId, 'creditId': creditId});
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> applyCreditToInvoice(int creditId, int invoiceId, double amount) async {
    try {
      await _db.execute('''
        UPDATE credits 
        SET montant = montant - ?, invoice_id = ?
        WHERE id = ? AND (montant - ?) >= 0
      ''', {'amount': amount, 'invoiceId': invoiceId, 'creditId': creditId});
      
      return true;
    } catch (e) {
      return false;
    }
  }
}





