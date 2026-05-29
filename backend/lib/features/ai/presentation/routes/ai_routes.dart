import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/ai_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';

class AIRoutes {
  late final Router router;

  AIRoutes() {
    final secured = Pipeline().addMiddleware(requireAuth());
    router = Router()
      ..get(
        '/project-risks',
        secured
            .addMiddleware(requireAnyPermission(
                ['view_ai_dashboard', 'view_statistics', 'manage_system']))
            .addHandler(_getProjectRisks),
      )
      ..get(
        '/payment-behavior',
        secured
            .addMiddleware(requireAnyPermission([
              'view_ai_dashboard',
              'view_ai_financial',
              'view_financial_reports',
              'view_statistics',
              'manage_system',
            ]))
            .addHandler(_getPaymentBehavior),
      )
      ..get(
        '/completion-forecasts',
        secured
            .addMiddleware(requireAnyPermission(
                ['view_ai_dashboard', 'view_statistics', 'manage_system']))
            .addHandler(_getCompletionForecasts),
      )
      ..get(
        '/employee-performance',
        secured
            .addMiddleware(requireAnyPermission(
                ['view_ai_dashboard', 'view_statistics', 'manage_system']))
            .addHandler(_getEmployeePerformance),
      )
      ..get(
        '/dashboard/summary',
        secured
            .addMiddleware(requireAnyPermission(
                ['view_ai_dashboard', 'view_statistics', 'manage_system']))
            .addHandler(_getDashboardSummary),
      )
      ..get(
        '/expense-anomalies',
        secured
            .addMiddleware(requireAnyPermission([
              'view_ai_dashboard',
              'view_ai_financial',
              'view_financial_reports',
              'view_statistics',
              'manage_system',
            ]))
            .addHandler(_getExpenseAnomalies),
      )
      ..get(
        '/strategic-insights',
        secured
            .addMiddleware(requireAnyPermission(
                ['view_ai_dashboard', 'view_statistics', 'manage_system']))
            .addHandler(_getStrategicInsights),
      );
  }

  String? _userId(Request request) {
    final user = request.context['user'];
    if (user is Map) {
      return user['sub']?.toString() ?? user['id']?.toString();
    }
    return null;
  }

  Future<Response> _getProjectRisks(Request request) async {
    final res = await AIService.analyzeProjectRisks(userId: _userId(request));
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getPaymentBehavior(Request request) async {
    final res = await AIService.analyzePaymentBehavior(userId: _userId(request));
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getCompletionForecasts(Request request) async {
    final res = await AIService.analyzeCompletionForecasts(userId: _userId(request));
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getEmployeePerformance(Request request) async {
    final res = await AIService.analyzeEmployeePerformance(userId: _userId(request));
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getDashboardSummary(Request request) async {
    final res = await AIService.getDashboardSummary();
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getExpenseAnomalies(Request request) async {
    final res = await AIService.scanExpenseAnomalies(userId: _userId(request));
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getStrategicInsights(Request request) async {
    final res = await AIService.getIntelligentInsights();
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }
}
