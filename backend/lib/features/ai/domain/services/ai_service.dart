import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:http/http.dart' as http;
import '../../../../core/config/runtime_config.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/repositories/ai_prediction_repository.dart';

class AIService {
  static final AIRepository _repository = AIRepository();
  static final AIPredictionRepository _predictionRepo = AIPredictionRepository();
  static dotenv.DotEnv? _dotEnv;

  /// Platform env → RuntimeConfig → backend `.env` (same order as DB/JWT).
  static String _config(String key, [String fallback = '']) {
    final fromRuntime = RuntimeConfig.get(key);
    if (fromRuntime != null && fromRuntime.trim().isNotEmpty) {
      return fromRuntime.trim();
    }
    final fromPlatform = Platform.environment[key];
    if (fromPlatform != null && fromPlatform.trim().isNotEmpty) {
      return fromPlatform.trim();
    }
    _dotEnv ??= dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
    return _dotEnv![key]?.trim() ?? fallback;
  }

  static String get _aiBaseUrl => _config('AI_SERVICE_URL', 'http://localhost:8001');
  static String get _aiApiKey => _config('AI_API_KEY', '');

  static Map<String, String> get _aiHeaders => {
        'Content-Type': 'application/json',
        if (_aiApiKey.isNotEmpty) 'X-API-Key': _aiApiKey,
      };

  static Future<Map<String, dynamic>?> _postAi(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_aiApiKey.isEmpty) {
      return null;
    }
    try {
      final response = await http
          .post(
            Uri.parse('$_aiBaseUrl$path'),
            headers: _aiHeaders,
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      print('AI HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('AI call error [$path]: $e');
    }
    return null;
  }

  static String _riskBand(double probability) {
    if (probability >= 0.75) return 'CRITICAL';
    if (probability >= 0.5) return 'HIGH';
    if (probability >= 0.35) return 'MEDIUM';
    return 'LOW';
  }

  /// Predicts project delays using the Python AI service.
  static Future<Map<String, dynamic>> analyzeProjectRisks({String? userId}) async {
    try {
      if (_aiApiKey.isEmpty) {
        return {
          'success': false,
          'message':
              'Service IA non configuré (AI_API_KEY manquant sur le backend).',
        };
      }

      final projects = await _repository.getProjectsForPrediction();
      if (projects.isEmpty) {
        return {
          'success': true,
          'data': {
            'predictions': [],
            'summary': 'Aucun projet actif à analyser.',
            'model_version': 'heuristic-v1',
          },
        };
      }

      final predictions = <Map<String, dynamic>>[];
      var highRiskCount = 0;
      var aiFailures = 0;

      final tasks = projects.map((p) async {
        final projectId = p['id']?.toString() ?? '';
        final totalTasks = int.tryParse(p['total_tasks']?.toString() ?? '0') ?? 0;
        final completedTasks =
            int.tryParse(p['completed_tasks']?.toString() ?? '0') ?? 0;
        final delayedTasks =
            int.tryParse(p['delayed_tasks']?.toString() ?? '0') ?? 0;
        final daysRemaining =
            int.tryParse(p['days_remaining']?.toString() ?? '14') ?? 14;
        final teamAvailability =
            double.tryParse(p['team_availability']?.toString() ?? '0.85') ?? 0.85;

        final features = {
          'total_tasks': totalTasks,
          'completed_tasks': completedTasks,
          'delayed_tasks': delayedTasks,
          'team_availability': teamAvailability,
          'days_remaining': daysRemaining,
          'priorite': p['priorite']?.toString() ?? 'Moyenne',
          'team_size': int.tryParse(p['team_size']?.toString() ?? '1') ?? 1,
          'client_outstanding':
              double.tryParse(p['client_outstanding']?.toString() ?? '0') ?? 0,
        };

        await _predictionRepo.saveFeatureSnapshot(
          entityType: 'project',
          entityId: projectId,
          features: features,
        );

        final body = await _postAi('/v1/predict/project-delay', {
          'project_id': int.tryParse(projectId),
          'features': features,
        });

        // Legacy fallback
        final legacy = body ??
            await _postAi('/ai/predict-delay', {
              'total_tasks': totalTasks,
              'completed_tasks': completedTasks,
              'delayed_tasks': delayedTasks,
              'team_availability': teamAvailability,
              'days_remaining': daysRemaining,
            });

        if (legacy == null) {
          aiFailures++;
          return null;
        }

        final data = legacy['data'] as Map<String, dynamic>? ?? legacy;
        final rawScore = data['delay_probability'] ?? data['risk_score'] ?? 0.0;
        final probability = rawScore is num
            ? rawScore.toDouble()
            : (double.tryParse(rawScore.toString()) ?? 0.0);

        final band = data['risk_band']?.toString() ?? _riskBand(probability);
        if (band == 'HIGH' || band == 'CRITICAL') highRiskCount++;

        final explanation = data['explanation'] as Map<String, dynamic>?;
        final model = legacy['model'] as Map<String, dynamic>?;

        await _predictionRepo.savePrediction(
          modelName: model?['name']?.toString() ?? 'project_delay',
          modelVersion: model?['version']?.toString() ?? 'heuristic-v1',
          entityType: 'project',
          entityId: projectId,
          predictionType: 'project_delay',
          score: probability,
          labelPredicted: band,
          confidence: (data['confidence'] as num?)?.toDouble(),
          explanation: explanation,
          requestedBy: userId,
        );

        return {
          'project_id': projectId,
          'project_name': p['nom'],
          'delay_probability': probability,
          'risk_band': band,
          'explanation': explanation,
          'delayed_tasks': delayedTasks,
          'days_remaining': daysRemaining,
        };
      });

      final results = await Future.wait(tasks);
      predictions.addAll(results.whereType<Map<String, dynamic>>());

      if (predictions.isEmpty && aiFailures > 0) {
        return {
          'success': false,
          'message':
              'Service IA indisponible. Vérifiez AI_SERVICE_URL et AI_API_KEY.',
        };
      }

      await _predictionRepo.upsertKpi(
        kpiCode: 'projects_high_risk',
        value: highRiskCount.toDouble(),
      );

      final partial = aiFailures > 0 && predictions.isNotEmpty;
      return {
        'success': true,
        'data': {
          'predictions': predictions,
          'high_risk_count': highRiskCount,
          'summary': partial
              ? 'Analyse partielle : ${predictions.length}/${projects.length} projet(s).'
              : 'Analyse de ${predictions.length} projet(s) via le service ML.',
          'model_version': 'heuristic-v1',
          if (partial) 'warning': 'Certaines prédictions IA ont échoué.',
        },
      };
    } catch (e) {
      print('AI Project Risk Error: $e');
      return {
        'success': false,
        'message': 'Service IA indisponible. Vérifiez AI_SERVICE_URL et AI_API_KEY.',
      };
    }
  }

  /// Analyzes client payment behavior.
  static Future<Map<String, dynamic>> analyzePaymentBehavior({String? userId}) async {
    try {
      if (_aiApiKey.isEmpty) {
        return {
          'success': false,
          'message': 'Service IA non configuré (AI_API_KEY manquant).',
        };
      }

      final clients = await _repository.getClientPaymentAggregates();
      if (clients.isEmpty) {
        return {
          'success': true,
          'data': {'client_scores': [], 'summary': 'Données insuffisantes.'},
        };
      }

      final clientScores = <Map<String, dynamic>>[];
      var aiFailures = 0;

      final tasks = clients.map((c) async {
        final clientId = c['client_id']?.toString() ?? '';
        final totalInvoiced =
            double.tryParse(c['total_invoiced_12m']?.toString() ?? '0') ?? 0;
        final totalPaid =
            double.tryParse(c['total_paid_12m']?.toString() ?? '0') ?? 0;
        final lateCount =
            int.tryParse(c['late_invoice_count']?.toString() ?? '0') ?? 0;
        final avgDelay =
            double.tryParse(c['avg_payment_delay_days']?.toString() ?? '0') ??
                0;

        final features = {
          'total_amount': totalInvoiced,
          'paid_amount': totalPaid,
          'late_payments': lateCount,
          'avg_payment_delay': avgDelay,
          'client_outstanding':
              double.tryParse(c['solde_du']?.toString() ?? '0') ?? 0,
        };

        final body = await _postAi('/v1/predict/payment-risk', {
          'client_id': int.tryParse(clientId),
          'features': features,
        });

        final legacy = body ??
            await _postAi('/ai/client-risk', {
              'total_amount': totalInvoiced,
              'paid_amount': totalPaid,
              'late_payments': lateCount,
              'avg_payment_delay': avgDelay,
            });

        if (legacy == null) {
          aiFailures++;
          return null;
        }

        final data = legacy['data'] as Map<String, dynamic>? ?? legacy;
        final riskLevel = data['risk_level']?.toString() ?? 'MEDIUM';
        final lateProb = (data['late_payment_probability'] as num?)?.toDouble();

        final reliability = riskLevel == 'LOW'
            ? 'A'
            : (riskLevel == 'MEDIUM' ? 'B' : (riskLevel == 'HIGH' ? 'C' : 'D'));

        await _predictionRepo.savePrediction(
          modelName: 'payment_risk',
          modelVersion: 'heuristic-v1',
          entityType: 'client',
          entityId: clientId,
          predictionType: 'payment_risk',
          score: lateProb,
          labelPredicted: riskLevel,
          explanation: data['explanation'] as Map<String, dynamic>?,
          requestedBy: userId,
        );

        return {
          'client_id': clientId,
          'client_name': c['raison_sociale'] ?? c['nom'],
          'reliability_score': reliability,
          'risk_level': riskLevel,
          'avg_delay_days': avgDelay.round(),
          'behavior_type': riskLevel == 'HIGH' || riskLevel == 'CRITICAL'
              ? 'Risqué'
              : 'Stable',
          'late_payment_probability': lateProb,
          'explanation': data['explanation'],
        };
      });

      final results = await Future.wait(tasks);
      clientScores.addAll(results.whereType<Map<String, dynamic>>());

      if (clientScores.isEmpty && aiFailures > 0) {
        return {
          'success': false,
          'message': 'Service IA indisponible.',
        };
      }

      return {
        'success': true,
        'data': {
          'client_scores': clientScores,
          'analyzed_count': clientScores.length,
          if (aiFailures > 0 && clientScores.isNotEmpty)
            'warning': 'Analyse partielle des clients.',
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Service IA indisponible.'};
    }
  }

  /// Completion time estimates for active projects.
  static Future<Map<String, dynamic>> analyzeCompletionForecasts({String? userId}) async {
    if (_aiApiKey.isEmpty) {
      return {
        'success': false,
        'message': 'Service IA non configuré (AI_API_KEY manquant).',
      };
    }

    final projects = await _repository.getProjectsForPrediction();
    if (projects.isEmpty) {
      return {'success': true, 'data': {'forecasts': []}};
    }

    final forecasts = <Map<String, dynamic>>[];
    var aiFailures = 0;

    for (final p in projects) {
      final openTasks = (int.tryParse(p['total_tasks']?.toString() ?? '0') ?? 0) -
          (int.tryParse(p['completed_tasks']?.toString() ?? '0') ?? 0);
      final teamSize = int.tryParse(p['team_size']?.toString() ?? '1') ?? 1;
      final avgAccuracy =
          double.tryParse(p['avg_estimate_accuracy']?.toString() ?? '1') ?? 1.0;
      final avgTaskDuration = (8.0 * avgAccuracy).clamp(2.0, 40.0);

      final body = await _postAi('/v1/predict/completion-time', {
        'project_id': int.tryParse(p['id']?.toString() ?? ''),
        'features': {
          'nb_tasks': openTasks,
          'avg_task_duration': avgTaskDuration,
          'team_size': teamSize,
        },
      });

      final legacy = body ??
          await _postAi('/ai/estimate-duration', {
            'nb_tasks': openTasks,
            'avg_task_duration': avgTaskDuration,
            'team_size': teamSize,
          });

      if (legacy == null) {
        aiFailures++;
        continue;
      }

      final data = legacy['data'] as Map<String, dynamic>? ?? legacy;
      final days = data['estimated_days_remaining'] ??
          data['estimated_days_remaining'];

      forecasts.add({
        'project_id': p['id'],
        'project_name': p['nom'],
        'estimated_days_remaining': days,
        'open_tasks': openTasks,
      });
    }

    if (forecasts.isEmpty && aiFailures > 0) {
      return {
        'success': false,
        'message': 'Service IA indisponible.',
      };
    }

    return {
      'success': true,
      'data': {
        'forecasts': forecasts,
        if (aiFailures > 0 && forecasts.isNotEmpty)
          'warning': 'Analyse partielle des prévisions.',
      },
    };
  }

  /// Employee productivity batch analysis.
  static Future<Map<String, dynamic>> analyzeEmployeePerformance({String? userId}) async {
    if (_aiApiKey.isEmpty) {
      return {
        'success': false,
        'message': 'Service IA non configuré (AI_API_KEY manquant).',
      };
    }

    final employees = await _repository.getEmployeeProductivityFeatures();
    if (employees.isEmpty) {
      return {'success': true, 'data': {'employees': []}};
    }

    final results = <Map<String, dynamic>>[];
    var aiFailures = 0;

    for (final e in employees) {
      final totalDays = int.tryParse(e['total_days']?.toString() ?? '22') ?? 22;
      final absentDays = int.tryParse(e['absent_days']?.toString() ?? '0') ?? 0;
      final lateDays = int.tryParse(e['late_days']?.toString() ?? '0') ?? 0;
      final assigned =
          int.tryParse(e['assigned_tasks_30d']?.toString() ?? '0') ?? 0;
      final completed =
          int.tryParse(e['completed_tasks_30d']?.toString() ?? '0') ?? 0;

      final body = await _postAi('/v1/predict/employee-performance', {
        'employee_id': e['employee_id']?.toString(),
        'features': {
          'total_days': totalDays,
          'absent_days': absentDays,
          'late_days': lateDays,
          'completed_tasks': completed,
          'assigned_tasks': assigned,
          'active_projects':
              int.tryParse(e['active_projects']?.toString() ?? '0') ?? 0,
        },
      });

      final legacy = body ??
          await _postAi('/ai/employee-performance', {
            'total_days': totalDays,
            'absent_days': absentDays,
            'late_days': lateDays,
            'completed_tasks': completed,
            'assigned_tasks': assigned,
          });

      if (legacy == null) {
        aiFailures++;
        continue;
      }

      final data = legacy['data'] as Map<String, dynamic>? ?? legacy;
      results.add({
        'employee_id': e['employee_id'],
        'employee_name': e['employee_name'],
        'performance_score': data['performance_score'],
        'absence_rate': data['absence_rate'],
        'workload_index': data['workload_index'],
        'explanation': data['explanation'],
      });
    }

    if (results.isEmpty && aiFailures > 0) {
      return {
        'success': false,
        'message': 'Service IA indisponible.',
      };
    }

    return {
      'success': true,
      'data': {
        'employees': results,
        if (aiFailures > 0 && results.isNotEmpty)
          'warning': 'Analyse partielle des performances.',
      },
    };
  }

  /// Dashboard summary + KPIs.
  static Future<Map<String, dynamic>> getDashboardSummary() async {
    final summary = await _repository.getDashboardSummary();
    var modelStatus = <String, dynamic>{};
    try {
      if (_aiApiKey.isNotEmpty) {
        final statusRes = await http
            .get(
              Uri.parse('$_aiBaseUrl/v1/models/status'),
              headers: _aiHeaders,
            )
            .timeout(const Duration(seconds: 5));
        if (statusRes.statusCode == 200) {
          modelStatus = jsonDecode(statusRes.body) as Map<String, dynamic>;
        }
      }
    } catch (_) {}

    return {
      'success': true,
      'data': {
        'kpis': summary,
        'models': modelStatus,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }

  /// Strategic recommendations from latest predictions.
  static Future<Map<String, dynamic>> getIntelligentInsights() async {
    final summary = await _repository.getDashboardSummary();
    final recommendations = <String>[];

    final highRisk =
        int.tryParse(summary['overdue_invoices']?.toString() ?? '0') ?? 0;
    if (highRisk > 0) {
      recommendations.add(
        '$highRisk facture(s) en retard — renforcer le recouvrement clients à risque.',
      );
    }

    final activeProjects =
        int.tryParse(summary['active_projects']?.toString() ?? '0') ?? 0;
    if (activeProjects > 0) {
      recommendations.add(
        'Surveiller les $activeProjects projet(s) actifs via les indicateurs de retard IA.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Situation stable — maintenir le suivi hebdomadaire des KPI IA.',
      );
    }

    return {
      'success': true,
      'data': {'recommendations': recommendations, 'kpis': summary},
    };
  }

  /// Expense anomaly scan (batch).
  static Future<Map<String, dynamic>> scanExpenseAnomalies({String? userId}) async {
    if (_aiApiKey.isEmpty) {
      return {
        'success': false,
        'message': 'Service IA non configuré (AI_API_KEY manquant).',
      };
    }

    final expenses = await _repository.getExpensesForAnomalyScan();
    if (expenses.isEmpty) {
      return {'success': true, 'data': {'anomalies': []}};
    }

    final amounts = expenses
        .map((e) => double.tryParse(e['montant']?.toString() ?? '0') ?? 0)
        .toList();

    final body = await _postAi('/v1/detect/expense-anomalies', {
      'expenses': expenses
          .map((e) => {
                'id': e['id'],
                'expense_type': e['expense_type'],
                'montant': double.tryParse(e['montant']?.toString() ?? '0'),
                'category_id': e['category_id'],
                'status': e['status'],
              })
          .toList(),
      'amount_stats': {
        'mean': amounts.isEmpty
            ? 0
            : amounts.reduce((a, b) => a + b) / amounts.length,
        'max': amounts.isEmpty ? 0 : amounts.reduce((a, b) => a > b ? a : b),
      },
    });

    if (body == null) {
      return {'success': false, 'message': 'Service IA indisponible.'};
    }

    return {'success': true, 'data': body['data'] ?? body};
  }
}
