import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../data/repositories/ai_repository.dart';

class AIService {
  static final AIRepository _repository = AIRepository();
  
  // Internal AI Microservice config (moved to .env or defaulted)
  static String get _aiBaseUrl => Platform.environment['AI_SERVICE_URL'] ?? 'http://localhost:8001';
  static String get _aiApiKey => Platform.environment['AI_API_KEY'] ?? '';

  /// Predicts project delays using the Python ML service.
  static Future<Map<String, dynamic>> analyzeProjectRisks() async {
    try {
      final projects = await _repository.getProjectsForPrediction();
      if (projects.isEmpty) return {'success': true, 'data': {'predictions': [], 'summary': 'No active projects.'}};

      final List<Map<String, dynamic>> predictions = [];

      // P1 FIX: Parallelize microservice calls to prevent sequential blocking/timeouts
      final tasks = projects.map((p) async {
        try {
          final response = await http.post(
            Uri.parse('$_aiBaseUrl/ai/predict-delay'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _aiApiKey
            },
            body: jsonEncode({
              'total_tasks': int.tryParse(p['total_tasks'].toString()) ?? 0,
              'completed_tasks': int.tryParse(p['completed_tasks'].toString()) ?? 0,
              'delayed_tasks': 0, 
              'team_availability': 0.85,
              'days_remaining': 14, 
            }),
          ).timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            final body = jsonDecode(response.body);
            return {
              'project_name': p['nom'],
              'delay_probability': body['data']['risk_score'],
            };
          }
        } catch (_) {}
        return null;
      });

      final results = await Future.wait(tasks);
      predictions.addAll(results.whereType<Map<String, dynamic>>());

      return {
        'success': true,
        'data': {
          'predictions': predictions,
          'summary': 'Analyse multi-projets basée sur le service ML local.'
        }
      };
    } catch (e) {
      print('AI Project Risk Error: $e');
      return {'success': false, 'message': 'Python AI Service not reachable.'};
    }
  }

  /// Analyzes client behavior using the Python ML service.
  static Future<Map<String, dynamic>> analyzePaymentBehavior() async {
    try {
      final history = await _repository.getClientPaymentHistory();
      if (history.isEmpty) return {'success': true, 'data': {'client_scores': []}};

      final List<Map<String, dynamic>> clientScores = [];

      final scoreTasks = history.map((h) async {
        try {
          final response = await http.post(
            Uri.parse('$_aiBaseUrl/ai/client-risk'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _aiApiKey
            },
            body: jsonEncode({
              'total_amount': double.tryParse(h['montant_ttc'].toString()) ?? 0.0,
              'paid_amount': double.tryParse(h['total_paid']?.toString() ?? '0.0') ?? 0.0,
              'late_payments': h['invoice_status'] == 'En retard' ? 1 : 0,
              'avg_payment_delay': 5.0,
            }),
          ).timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            final body = jsonDecode(response.body);
            return {
              'client_name': h['raison_sociale'] ?? h['nom'],
              'reliability_score': body['data']['risk_level'] == 'LOW' ? 'A' : (body['data']['risk_level'] == 'MEDIUM' ? 'B' : 'D'),
              'avg_delay_days': 5,
              'behavior_type': body['data']['risk_level'] == 'HIGH' ? 'Risqué' : 'Stable'
            };
          }
        } catch (_) {}
        return null;
      });

      final results = await Future.wait(scoreTasks);
      clientScores.addAll(results.whereType<Map<String, dynamic>>());

      return {
        'success': true,
        'data': {
          'client_scores': clientScores
        }
      };
    } catch (e) {
      return {'success': false, 'message': 'Python AI Service not reachable.'};
    }
  }

  /// Provides high-level strategic insights.
  static Future<Map<String, dynamic>> getIntelligentInsights() async {
    return {
      'success': true, 
      'data': {
        'recommendations': [
          "Optimiser l'allocation des ressources sur les projets à haut risque.",
          "Renforcer le suivi des paiements pour les clients catégorisés 'D'.",
          "Maintenir la cadence actuelle pour les employés à haute performance."
        ]
      }
    };
  }
}
