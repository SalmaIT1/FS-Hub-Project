import 'dart:convert';
import 'dart:io';

import 'package:fs_hub_backend/core/config/runtime_config.dart';
import 'package:fs_hub_backend/core/middleware/auth_middleware.dart';
import 'package:fs_hub_backend/core/middleware/permission_middleware.dart';
import 'package:fs_hub_backend/core/services/redis_service.dart';
import 'package:fs_hub_backend/features/ai/presentation/routes/ai_routes.dart';
import 'package:fs_hub_backend/features/auth/presentation/routes/auth_routes.dart';
import 'package:fs_hub_backend/features/auth/presentation/routes/role_permission_routes.dart';
import 'package:fs_hub_backend/features/chat/presentation/routes/conversation_routes.dart';
import 'package:fs_hub_backend/features/chat/presentation/websocket/websocket_server.dart';
import 'package:fs_hub_backend/features/client/presentation/routes/client_routes.dart';
import 'package:fs_hub_backend/features/demand/presentation/routes/demand_routes.dart';
import 'package:fs_hub_backend/features/department/presentation/routes/department_routes.dart';
import 'package:fs_hub_backend/features/email/presentation/routes/email_routes.dart';
import 'package:fs_hub_backend/features/employee/presentation/routes/employee_routes.dart';
import 'package:fs_hub_backend/features/employees/presentation/routes/poste_routes.dart';
import 'package:fs_hub_backend/features/finance/presentation/routes/company_expenses_routes.dart';
import 'package:fs_hub_backend/features/finance/presentation/routes/credit_routes.dart';
import 'package:fs_hub_backend/features/finance/presentation/routes/finance_routes.dart';
import 'package:fs_hub_backend/features/finance/presentation/routes/project_expenses_routes.dart';
import 'package:fs_hub_backend/features/hr/presentation/routes/audit_routes.dart';
import 'package:fs_hub_backend/features/hr/presentation/routes/hr_routes.dart';
import 'package:fs_hub_backend/features/media/presentation/routes/media_routes.dart';
import 'package:fs_hub_backend/features/media/presentation/routes/upload_routes.dart';
import 'package:fs_hub_backend/features/media/presentation/routes/voice_routes.dart';
import 'package:fs_hub_backend/features/notification/presentation/routes/notification_routes.dart';
import 'package:fs_hub_backend/features/project/presentation/routes/project_routes.dart';
import 'package:fs_hub_backend/features/sprint/presentation/routes/sprint_routes.dart';
import 'package:fs_hub_backend/features/task/presentation/routes/task_routes.dart';
import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const _rateLimitConfig = {
  'v1/auth/login': [10, 5],
  'v1/auth/forgot-password': [5, 15],
  'v1/auth/refresh': [20, 5],
};

/// Builds the Shelf router and middleware pipeline (shared by server + integration tests).
class HttpApp {
  HttpApp({WebSocketServer? webSocketServer, this.disableRateLimit = false})
      : webSocketServer = webSocketServer ?? WebSocketServer();

  final WebSocketServer webSocketServer;
  final bool disableRateLimit;

  Future<Response?> checkRateLimit(Request request, String ip) async {
    if (disableRateLimit || RuntimeConfig.disableRateLimit) return null;
    if (request.method != 'POST') return null;
    final path = request.url.path.replaceAll(RegExp(r'^\/'), '');
    final entry = _rateLimitConfig[path];
    if (entry == null) return null;

    final maxAttempts = entry[0];
    final windowMins = entry[1];
    try {
      final db = DBConnection.getConnection();
      final res = await db.execute(
        'SELECT COUNT(*) as cnt FROM rate_limit_attempts '
        'WHERE endpoint = :ep AND identifier = :ip '
        'AND attempted_at > DATE_SUB(NOW(), INTERVAL :win MINUTE)',
        {'ep': path, 'ip': ip, 'win': windowMins},
      );
      final count =
          int.tryParse(res.rows.first.colByName('cnt')?.toString() ?? '0') ?? 0;
      if (count >= maxAttempts) {
        return Response(
          429,
          body: jsonEncode({
            'success': false,
            'message':
                'Too many requests. Please wait $windowMins minutes.',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
      await db.execute(
        'INSERT INTO rate_limit_attempts (endpoint, identifier) VALUES (:ep, :ip)',
        {'ep': path, 'ip': ip},
      );
    } catch (e) {
      return Response(
        503,
        body: jsonEncode(
            {'success': false, 'message': 'Service temporarily unavailable'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
    return null;
  }

  Router createRouter() {
    Handler secured(Router r) =>
        Pipeline().addMiddleware(requireAuth()).addHandler(r.call);

    Handler adminOnly(Router r) => Pipeline()
        .addMiddleware(requireAuth())
        .addMiddleware(requireAdmin())
        .addHandler(r.call);

    Handler requireManageRoles(Router r) => Pipeline()
        .addMiddleware(requireAuth())
        .addMiddleware(requirePermission('manage_roles'))
        .addHandler(r.call);

    Handler requireFinanceAccess(Router r) => Pipeline()
        .addMiddleware(requireAuth())
        .addMiddleware(requireRoleOrPermission(
          ['Admin', 'Comptable', 'Manager', 'Client'],
          [
            'manage_finance',
            'view_finances',
            'view_invoices',
            'view_quotes',
            'manage_invoices',
          ],
        ))
        .addHandler(r.call);

    return Router()
      ..mount('/v1/auth', AuthRoutes().router.call)
      ..mount('/v1/demands', secured(DemandRoutes().router))
      ..mount('/v1/notifications', secured(NotificationRoutes().router))
      ..mount('/v1/employees', secured(EmployeeRoutes().router))
      ..mount('/v1/postes', secured(PosteRoutes().router))
      ..mount('/v1/roles', requireManageRoles(RolePermissionRoutes().router))
      ..mount('/v1/departments', secured(DepartmentRoutes().router))
      ..mount('/v1/projects', secured(ProjectRoutes().router))
      ..mount('/v1/sprints', secured(SprintRoutes().router))
      ..mount('/v1/tasks', secured(TaskRoutes().router))
      ..mount('/v1/clients', requireFinanceAccess(ClientRoutes().router))
      ..mount('/v1/hr', secured(HrRoutes().router))
      ..mount('/v1/ai', secured(AIRoutes().router))
      ..mount('/v1/audit', adminOnly(AuditRoutes().router))
      ..mount('/v1/email', secured(EmailRoutes().router))
      ..mount('/v1/conversations', secured(ConversationRoutes().router))
      ..mount('/v1/finance', requireFinanceAccess(FinanceRoutes().router))
      ..mount('/v1/credits', requireFinanceAccess(CreditRoutes().router))
      ..mount(
          '/v1/project-expenses', requireFinanceAccess(ProjectExpensesRoutes().router))
      ..mount(
          '/v1/company-expenses', requireFinanceAccess(CompanyExpensesRoutes().router))
      ..mount('/v1/uploads', secured(UploadRoutes().router))
      ..mount('/media', secured(MediaRoutes().router))
      ..mount('/voice', secured(VoiceRoutes().router))
      ..mount('/ws', webSocketServer.router.call)
      ..get('/healthz', (Request request) async {
        try {
          final db = DBConnection.getConnection();
          await db.execute('SELECT 1');
          return Response.ok(
            jsonEncode({
              'status': 'ok',
              'db': 'connected',
              'redis': 'checked',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({'status': 'error', 'details': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      });
  }

  Handler createHandler({String? corsOrigin}) {
    final router = createRouter();

    Map<String, String> corsHeaders(Request request) {
      final origin = request.headers['origin'] ?? '';
      final isLocal = origin.startsWith('http://localhost') ||
          origin.startsWith('https://localhost') ||
          origin.startsWith('http://127.0.0.1');

      var isAllowed = isLocal || origin.isEmpty;
      if (corsOrigin != null && origin == corsOrigin) {
        isAllowed = true;
      }

      return {
        'Access-Control-Allow-Origin':
            isAllowed && origin.isNotEmpty ? origin : '',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers':
            'Origin, Content-Type, Accept, Authorization, X-User-Id, ngrok-skip-browser-warning, x-idempotency-key',
        'Access-Control-Allow-Credentials': 'true',
        'Access-Control-Max-Age': '86400',
      };
    }

    return Pipeline()
        .addMiddleware((innerHandler) {
          return (Request request) async {
            final cors = corsHeaders(request);
            if (request.method == 'OPTIONS') {
              return Response.ok('', headers: cors);
            }
            try {
              final response = await innerHandler(request);
              if (response.statusCode == 101 ||
                  (response.headers['connection']?.toLowerCase() == 'upgrade')) {
                return response;
              }
              final newHeaders = Map<String, String>.from(response.headers);
              cors.forEach((key, value) => newHeaders[key] = value);
              return response.change(headers: newHeaders);
            } catch (e, stack) {
              print('[SERVER-ERROR] $e\n$stack');
              return Response.internalServerError(
                body: jsonEncode({
                  'success': false,
                  'message': 'Internal server error',
                }),
                headers: {...cors, 'Content-Type': 'application/json'},
              );
            }
          };
        })
        .addMiddleware((innerHandler) {
          return (Request request) async {
            final path = request.requestedUri.path;
            if ((path.contains('/v1/uploads') || path.contains('/media')) &&
                (request.method == 'PUT' || request.method == 'POST')) {
              return innerHandler(request);
            }
            final contentLength =
                int.tryParse(request.headers['content-length'] ?? '0') ?? 0;
            if (contentLength > 10 * 1024 * 1024) {
              return Response(
                413,
                body: jsonEncode({
                  'success': false,
                  'message': 'Request body too large (10MB limit)',
                }),
                headers: {'Content-Type': 'application/json; charset=utf-8'},
              );
            }
            return innerHandler(request);
          };
        })
        .addMiddleware((innerHandler) {
          return (Request request) async {
            final ip = _clientIp(request);
            final limited = await checkRateLimit(request, ip);
            if (limited != null) return limited;
            return innerHandler(request);
          };
        })
        .addMiddleware((innerHandler) {
          return (Request request) async {
            if (request.method == 'POST') {
              final idempotencyKey = request.headers['x-idempotency-key'];
              if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
                final ok =
                    await RedisService().checkAndSetIdempotencyKey(idempotencyKey);
                if (ok == null) {
                  return innerHandler(request);
                }
                if (!ok) {
                  return Response(
                    409,
                    body: jsonEncode({
                      'success': false,
                      'message':
                          'Idempotent request already processed or in progress',
                    }),
                    headers: {'Content-Type': 'application/json; charset=utf-8'},
                  );
                }
              }
            }
            return innerHandler(request);
          };
        })
        .addMiddleware(logRequests())
        .addMiddleware((innerHandler) {
          return (Request request) async {
            try {
              return await innerHandler(request);
            } catch (e, stack) {
              if (e.toString().contains('underlying data stream was hijacked')) {
                rethrow;
              }
              print(jsonEncode({
                'level': 'ERROR',
                'message': e.toString(),
                'stack_trace': stack.toString(),
                'path': request.url.path,
                'method': request.method,
              }));
              final isBusinessLogic = e is Exception;
              return Response(
                isBusinessLogic ? 400 : 500,
                body: jsonEncode({
                  'success': false,
                  'message': isBusinessLogic
                      ? e.toString().replaceFirst('Exception: ', '')
                      : 'An internal server error occurred',
                }),
                headers: {'Content-Type': 'application/json; charset=utf-8'},
              );
            }
          };
        })
        .addHandler(router.call);
  }


String _clientIp(Request request) {
  final forwarded = request.headers['x-forwarded-for'] ??
      request.headers['X-Forwarded-For'];
  if (forwarded != null && forwarded.isNotEmpty) {
    return forwarded.split(',').first.trim();
  }
  final connInfo = request.context['shelf.io.connection_info'];
  if (connInfo != null) {
    try {
      final addr = (connInfo as dynamic).remoteAddress?.address?.toString();
      if (addr != null && addr.isNotEmpty) return addr;
    } catch (_) {}
  }
  return 'unknown';
}
}
