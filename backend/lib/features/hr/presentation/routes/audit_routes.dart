import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../../../shared/services/audit_service.dart';

class AuditRoutes {
  Router get router {
    final router = Router();

    // GET /v1/hr/audit-logs
    router.get('/audit-logs', (Request request) async {
      try {
        final query = request.url.queryParameters;
        final limit = int.tryParse(query['limit'] ?? '100') ?? 100;
        final action = query['action'];
        final userId = query['userId'];
        final startDate = query['startDate'];
        final endDate = query['endDate'];

        final logs = await AuditService.getLogs(
          limit: limit,
          action: action,
          userId: userId,
          startDate: startDate,
          endDate: endDate,
        );

        return Response.ok(
          jsonEncode({'success': true, 'data': logs}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
    });

    // POST /v1/audit/log
    router.post('/log', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final userId = request.context['userId']?.toString() ?? 'SYSTEM';
        final action = body['action']?.toString() ?? 'UNKNOWN';
        final details = body['details'] as Map<String, dynamic>? ?? {};

        await AuditService.log(userId, action, details);

        return Response.ok(
          jsonEncode({'success': true, 'message': 'Logged successfully'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
    });

    return router;
  }
}
