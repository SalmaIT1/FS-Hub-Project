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
      ..get('/project-risks', secured
        .addMiddleware(requirePermission('view_statistics'))
        .addHandler(_getProjectRisks))
      ..get('/payment-behavior', secured
        .addMiddleware(requirePermission('view_financial_reports'))
        .addHandler(_getPaymentBehavior))
      ..get('/strategic-insights', secured
        .addMiddleware(requirePermission('manage_system'))
        .addHandler(_getStrategicInsights));
  }

  Future<Response> _getProjectRisks(Request request) async {
    final res = await AIService.analyzeProjectRisks();
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getPaymentBehavior(Request request) async {
    final res = await AIService.analyzePaymentBehavior();
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _getStrategicInsights(Request request) async {
    final res = await AIService.getIntelligentInsights();
    return Response.ok(jsonEncode(res), headers: {'Content-Type': 'application/json'});
  }
}
