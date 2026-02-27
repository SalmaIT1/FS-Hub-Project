import 'dart:convert';
import 'package:mysql_client/mysql_client.dart';
import '../database/db_connection.dart';

class CreditScoreService {
  static Future<Map<String, dynamic>> calculateClientCreditScore(int clientId) async {
    try {
      final conn = DBConnection.getConnection();
      
      // Calculate credit score based on unpaid amounts from projects
      final result = await conn.execute('''
        SELECT 
          c.id,
          c.nom,
          c.prenom,
          COALESCE(SUM(p.montant_total - COALESCE(SUM(pa.montant_paye), 0)), 0) as credit_score,
          COUNT(DISTINCT p.id) as total_projects,
          SUM(COALESCE(pa.montant_paye, 0)) as total_paid,
          SUM(p.montant_total) as total_project_value
        FROM clients c
        LEFT JOIN projects p ON c.id = p.client_id
        LEFT JOIN payments pa ON p.id = pa.project_id
        WHERE c.id = :client_id
        GROUP BY c.id, c.nom, c.prenom
      ''', {'client_id': clientId});

      if (result.rows.isEmpty) {
        return {
          'success': false,
          'message': 'Client not found',
          'credit_score': 0,
        };
      }

      final row = result.rows.first;
      final creditScore = row.colByName('credit_score') ?? 0;
      final totalProjects = row.colByName('total_projects') ?? 0;
      final totalPaid = row.colByName('total_paid') ?? 0;
      final totalValue = row.colByName('total_project_value') ?? 0;

      // Update the client's credit score in the database
      await conn.execute('''
        UPDATE clients 
        SET score_credit = :credit_score 
        WHERE id = :client_id
      ''', {
        'credit_score': creditScore,
        'client_id': clientId,
      });

      return {
        'success': true,
        'client_id': clientId,
        'credit_score': creditScore,
        'total_projects': totalProjects,
        'total_paid': totalPaid,
        'total_project_value': totalValue,
        'unpaid_amount': creditScore > 0 ? creditScore : 0,
        'message': creditScore > 0 
          ? 'Client has unpaid amount of $creditScore'
          : 'Client has no unpaid amounts',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error calculating credit score: $e',
        'credit_score': 0,
      };
    }
  }

  static Future<Map<String, dynamic>> getAllClientsWithCreditScores() async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT 
          c.id,
          c.nom,
          c.prenom,
          c.raison_sociale,
          c.email,
          c.telephone,
          c.type,
          COALESCE(c.score_credit, 0) as credit_score,
          COUNT(DISTINCT p.id) as total_projects,
          SUM(COALESCE(pa.montant_paye, 0)) as total_paid,
          SUM(p.montant_total) as total_project_value
        FROM clients c
        LEFT JOIN projects p ON c.id = p.client_id
        LEFT JOIN payments pa ON p.id = pa.project_id
        GROUP BY c.id, c.nom, c.prenom, c.raison_sociale, c.email, c.telephone, c.type, c.score_credit
        ORDER BY c.nom, c.prenom
      ''');

      final clients = result.rows.map((row) {
        return {
          'id': int.tryParse(row.colByName('id').toString()) ?? 0,
          'nom': row.colByName('nom'),
          'prenom': row.colByName('prenom'),
          'raison_sociale': row.colByName('raison_sociale'),
          'email': row.colByName('email'),
          'telephone': row.colByName('telephone'),
          'type': _convertTypeToFrontend(row.colByName('type')),
          'credit_score': row.colByName('credit_score'),
          'total_projects': row.colByName('total_projects') ?? 0,
          'total_paid': row.colByName('total_paid') ?? 0,
          'total_project_value': row.colByName('total_project_value') ?? 0,
          'unpaid_amount': (row.colByName('credit_score') ?? 0) > 0 ? row.colByName('credit_score') : 0,
        };
      }).toList();

      return {
        'success': true,
        'clients': clients,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching clients with credit scores: $e',
        'clients': [],
      };
    }
  }

  static Future<Map<String, dynamic>> getProjectPaymentHistory(int clientId) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT 
          p.id as project_id,
          p.titre,
          p.montant_total,
          p.statut,
          p.date_debut,
          p.date_fin_prevue,
          COALESCE(SUM(pa.montant_paye), 0) as amount_paid,
          p.montant_total - COALESCE(SUM(pa.montant_paye), 0) as remaining_amount
        FROM projects p
        LEFT JOIN payments pa ON p.id = pa.project_id
        WHERE p.client_id = :client_id
        GROUP BY p.id, p.titre, p.montant_total, p.statut, p.date_debut, p.date_fin_prevue
        ORDER BY p.date_debut DESC
      ''', {'client_id': clientId});

      final projects = result.rows.map((row) {
        return {
          'project_id': row.colByName('project_id'),
          'titre': row.colByName('titre'),
          'montant_total': row.colByName('montant_total'),
          'statut': row.colByName('statut'),
          'date_debut': row.colByName('date_debut'),
          'date_fin_prevue': row.colByName('date_fin_prevue'),
          'amount_paid': row.colByName('amount_paid'),
          'remaining_amount': row.colByName('remaining_amount'),
        };
      }).toList();

      return {
        'success': true,
        'projects': projects,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching payment history: $e',
        'projects': [],
      };
    }
  }

  // Helper function to convert database type to frontend enum format
  static String _convertTypeToFrontend(String dbType) {
    if (dbType == 'Entreprise') {
      return 'entreprise';
    } else if (dbType == 'Particulier') {
      return 'particulier';
    }
    return 'particulier';
  }
}
