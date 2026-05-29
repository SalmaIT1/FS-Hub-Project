import 'package:fs_hub/core/services/api_service.dart';

/// Client for `/v1/ai/*` — uses [ApiService] (ngrok header + auth + response unwrap).
class AiService {
  static Future<Map<String, dynamic>?> _fetch(String endpoint) async {
    final res = await ApiService.get('/ai/$endpoint');
    if (res['success'] == true) {
      final data = res['data'];
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{'items': data};
    }
    return {
      '_error': true,
      'message': res['error']?.toString() ??
          res['message']?.toString() ??
          'Erreur IA',
    };
  }

  static Future<Map<String, dynamic>?> getProjectRisks() =>
      _fetch('project-risks');

  static Future<Map<String, dynamic>?> getPaymentBehavior() =>
      _fetch('payment-behavior');

  static Future<Map<String, dynamic>?> getStrategicInsights() =>
      _fetch('strategic-insights');

  static Future<Map<String, dynamic>?> getDashboardSummary() =>
      _fetch('dashboard/summary');

  static Future<Map<String, dynamic>?> getCompletionForecasts() =>
      _fetch('completion-forecasts');

  static Future<Map<String, dynamic>?> getEmployeePerformance() =>
      _fetch('employee-performance');

  static Future<Map<String, dynamic>?> getExpenseAnomalies() =>
      _fetch('expense-anomalies');
}
