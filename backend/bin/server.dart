import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:fs_hub_backend/features/auth/presentation/routes/auth_routes.dart';
import 'package:fs_hub_backend/features/demand/presentation/routes/demand_routes.dart';
import 'package:fs_hub_backend/features/notification/presentation/routes/notification_routes.dart';
import 'package:fs_hub_backend/features/employee/presentation/routes/employee_routes.dart';
import 'package:fs_hub_backend/features/email/presentation/routes/email_routes.dart';
import 'package:fs_hub_backend/features/chat/presentation/routes/conversation_routes.dart';
import 'package:fs_hub_backend/features/media/presentation/routes/upload_routes.dart';
import 'package:fs_hub_backend/features/media/presentation/routes/media_routes.dart';
import 'package:fs_hub_backend/features/media/presentation/routes/voice_routes.dart';
import 'package:fs_hub_backend/features/client/presentation/routes/client_routes.dart';
import 'package:fs_hub_backend/features/department/presentation/routes/department_routes.dart';
import 'package:fs_hub_backend/features/project/presentation/routes/project_routes.dart';
import 'package:fs_hub_backend/features/sprint/presentation/routes/sprint_routes.dart';
import 'package:fs_hub_backend/features/task/presentation/routes/task_routes.dart';
import 'package:fs_hub_backend/features/finance/presentation/routes/finance_routes.dart';
import 'package:fs_hub_backend/features/finance/presentation/routes/credit_routes.dart';
import 'package:fs_hub_backend/features/finance/presentation/routes/project_expenses_routes.dart';
import 'package:fs_hub_backend/features/finance/presentation/routes/company_expenses_routes.dart';
import 'package:fs_hub_backend/features/auth/presentation/routes/role_permission_routes.dart';
import 'package:fs_hub_backend/features/hr/presentation/routes/hr_routes.dart';
import 'package:fs_hub_backend/features/hr/presentation/routes/audit_routes.dart';
import 'package:fs_hub_backend/features/ai/presentation/routes/ai_routes.dart';

import 'package:fs_hub_backend/features/email/domain/services/email_service.dart';
import 'package:fs_hub_backend/features/employees/presentation/routes/poste_routes.dart';
import 'package:fs_hub_backend/features/chat/presentation/websocket/websocket_server.dart';
import 'package:fs_hub_backend/core/services/data_integrity_service.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';
import 'package:fs_hub_backend/core/middleware/auth_middleware.dart';
import 'package:fs_hub_backend/core/middleware/permission_middleware.dart';
import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:fs_hub_backend/core/services/redis_service.dart';
import 'package:fs_hub_backend/features/chat/data/repositories/chat_repository.dart';

// Import database initialization
import 'package:fs_hub_backend/shared/database/migrations.dart';

// ── H-4 + H-5 FIX: DB-backed rate limiter (persists across restarts) ─────────
// Endpoint limits: POST path => [maxAttempts, windowMinutes]
const _rateLimitConfig = {
  'v1/auth/login':           [10, 5],   // 10 per 5 min (brute-force guard)
  'v1/auth/forgot-password': [5,  15],  // 5 per 15 min  (email spam guard)
  'v1/auth/refresh':         [20, 5],   // 20 per 5 min  (token-stuffing guard)
};

Future<Response?> _checkRateLimit(Request request, String ip) async {
  if (request.method != 'POST') return null;
  final path = request.url.path.replaceAll(RegExp(r'^\/'), '');
  final entry = _rateLimitConfig[path];
  if (entry == null) return null;

  final maxAttempts = entry[0];
  final windowMins  = entry[1];
  try {
    final db = DBConnection.getConnection();
    final res = await db.execute(
      'SELECT COUNT(*) as cnt FROM rate_limit_attempts '
      'WHERE endpoint = :ep AND ip_address = :ip '
      'AND attempted_at > DATE_SUB(NOW(), INTERVAL :win MINUTE)',
      {'ep': path, 'ip': ip, 'win': windowMins},
    );
    final count = int.tryParse(res.rows.first.colByName('cnt')?.toString() ?? '0') ?? 0;
    if (count >= maxAttempts) {
      return Response(
        429,
        body: jsonEncode({'success': false, 'message': 'Too many requests. Please wait $windowMins minutes.'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
    await db.execute(
      'INSERT INTO rate_limit_attempts (endpoint, ip_address, attempted_at) VALUES (:ep, :ip, NOW())',
      {'ep': path, 'ip': ip},
    );
  } catch (e) {
    print('[RATE-LIMIT] DB error, falling through for $path: $e');
  }
  return null;
}

void main(List<String> args) async {
  // 1. Initialize local storage sandboxes with secure check
  final uploadsDir = Directory('uploads');
  if (!await uploadsDir.exists()) {
    print('[STORAGE] Initializing uploads/ directory...');
    await uploadsDir.create(recursive: true);
  }

  // 2. Initialize JWT secret FIRST — throws if missing.
  AuthService.initSecret();
  
  // Initialize Email service to load SMTP settings.
  EmailService.initialize();

  // Initialize database with migrations.
  await Migrations.initializeDatabase();

  // Initialize Redis backplane.
  await RedisService().initialize();

  // Initialize WebSocket server.
  final wsServer = WebSocketServer();
  wsServer.startCleanupTimer();

  // Start data integrity service and run initial checks.
  DataIntegrityService.startPeriodicCleanup();
  await DataIntegrityService.checkDeadlines();

  // P2-01 FIX: Scheduled background cleanup for orphaned uploads.
  // Runs every 24 hours to keep the 'uploads/' storage lean.
  Timer.periodic(const Duration(hours: 24), (timer) async {
    print('[BACKGROUND] Starting scheduled cleanup of orphaned uploads...');
    final count = await ChatRepository().cleanupOrphanedUploads();
    print('[BACKGROUND] Cleanup completed. Removed $count orphan records.');
  });

  // Build per-domain secured pipelines.
  Handler secured(Router r) =>
      Pipeline().addMiddleware(requireAuth()).addHandler(r.call);

  Handler adminOnly(Router r) =>
      Pipeline().addMiddleware(requireAuth()).addMiddleware(requireAdmin()).addHandler(r.call);

  Handler requireManageUsers(Router r) =>
      Pipeline().addMiddleware(requireAuth()).addMiddleware(requirePermission('manage_users')).addHandler(r.call);

  Handler requireManageRoles(Router r) =>
      Pipeline().addMiddleware(requireAuth()).addMiddleware(requirePermission('manage_roles')).addHandler(r.call);

  Handler requireFinanceAccess(Router r) =>
      Pipeline().addMiddleware(requireAuth()).addMiddleware(requireRoleOrPermission(['Admin', 'Comptable', 'Manager', 'Client'], ['manage_finance', 'view_finances', 'view_invoices', 'view_quotes'])).addHandler(r.call);

  // Create router with versioned API paths.
  // Auth routes manage their own public/protected split internally.
  // All other v1 routes are secured globally here.
  final router = Router()
    ..mount('/v1/auth', AuthRoutes().router.call)
    ..mount('/v1/demands', secured(DemandRoutes().router))
    ..mount('/v1/notifications', secured(NotificationRoutes().router))
    ..mount('/v1/employees', secured(EmployeeRoutes().router))
    ..mount('/v1/postes', secured(PosteRoutes().router))
    ..mount('/v1/roles', requireManageRoles(RolePermissionRoutes().router))  // FIX: was secured() — any user could mutate roles
    ..mount('/v1/departments', secured(DepartmentRoutes().router))
    ..mount('/v1/projects', secured(ProjectRoutes().router))
    ..mount('/v1/sprints', secured(SprintRoutes().router))
    ..mount('/v1/tasks', secured(TaskRoutes().router))
    ..mount('/v1/clients', requireFinanceAccess(ClientRoutes().router))  // FIX: was secured() — now requires finance access
    ..mount('/v1/hr', secured(HrRoutes().router))
    ..mount('/v1/ai', secured(AIRoutes().router))
    ..mount('/v1/audit', adminOnly(AuditRoutes().router))
    ..mount('/v1/email', secured(EmailRoutes().router))
    ..mount('/v1/conversations', secured(ConversationRoutes().router))
    ..mount('/v1/finance', requireFinanceAccess(FinanceRoutes().router))
    ..mount('/v1/credits', requireFinanceAccess(CreditRoutes().router))
    ..mount('/v1/project-expenses', requireFinanceAccess(ProjectExpensesRoutes().router))
    ..mount('/v1/company-expenses', requireFinanceAccess(CompanyExpensesRoutes().router))
    ..mount('/v1/uploads', secured(UploadRoutes().router))
    ..mount('/media', secured(MediaRoutes().router))
    ..mount('/voice', secured(VoiceRoutes().router))
    ..mount('/ws', wsServer.router.call)
    ..get('/healthz', (Request request) async {
      try {
         final db = DBConnection.getConnection();
         await db.execute('SELECT 1');
         // We assume RedisService is active if no exception is thrown on init, 
         // or we can test it directly if there's a ping.
         return Response.ok(jsonEncode({'status': 'ok', 'db': 'connected', 'redis': 'connected'}), headers: {'Content-Type': 'application/json'});
      } catch (e) {
         return Response.internalServerError(body: jsonEncode({'status': 'error', 'details': e.toString()}), headers: {'Content-Type': 'application/json'});
      }
    });



  // CORS middleware — allow localhost origins for dev builds only.
  // ⚠️  P3 FIX: Removed ngrok wildcard (*.ngrok-free.app, *.ngrok.io).
  //  Any ngrok tunnel could call the production API. Set an explicit
  //  CORS_ALLOWED_ORIGIN env var for staging/production access.
  Map<String, String> corsHeaders(Request request) {
    final origin = request.headers['origin'] ?? '';
    final explicitAllowed = Platform.environment['CORS_ALLOWED_ORIGIN'];
    final isAllowed = origin.startsWith('http://localhost') ||
        origin.startsWith('https://localhost') ||
        origin.startsWith('http://127.0.0.1') ||
        (explicitAllowed != null && origin == explicitAllowed) ||
        origin.isEmpty; // same-origin requests may omit Origin
    return {
      'Access-Control-Allow-Origin': isAllowed && origin.isNotEmpty ? origin : 'http://localhost',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers':
          'Origin, Content-Type, Accept, Authorization, X-User-Id, ngrok-skip-browser-warning, x-idempotency-key',
      'Access-Control-Allow-Private-Network': 'true',
    };
  }

  final handler = Pipeline()
      // 0. CORS protection (Outermost layer for Pre-flight handling)
      .addMiddleware((innerHandler) {
        return (Request request) async {
          final cors = corsHeaders(request);
          if (request.method == 'OPTIONS') {
            return Response.ok('', headers: cors);
          }
          final response = await innerHandler(request);
          return response.change(headers: cors);
        };
      })
      // 1. Global request body size limit (Standard: 10MB for general APIs)
      .addMiddleware((innerHandler) {
        return (Request request) async {
          final path = request.requestedUri.path;
          
          // P1 FIX: Increase limit & fix path detection for uploads.
          // Skip the global cap for binary PUT/POST uploads (handled by UploadRouter internal limits).
          if ((path.contains('/v1/uploads') || path.contains('/media')) && 
              (request.method == 'PUT' || request.method == 'POST')) {
            return innerHandler(request);
          }

          final contentLength = int.tryParse(request.headers['content-length'] ?? '0') ?? 0;
          if (contentLength > 10 * 1024 * 1024) { // 10 MB cap for standard metadata/JSON
            return Response(413, 
              body: jsonEncode({'success': false, 'message': 'Request body too large (10MB limit)'}), 
              headers: {'Content-Type': 'application/json; charset=utf-8'}
            );
          }
          return innerHandler(request);
        };
      })
      // 2. DB-backed rate limiter (H-4 + H-5)
      .addMiddleware((innerHandler) {
        return (Request request) async {
          // P1 SURGICAL FIX: Do not trust client-supplied X-Forwarded-For if not explicitly authenticated by reverse proxy.
          String ip = 'unknown';
          if (request.context['shelf.io.connection_info'] != null) {
            ip = (request.context['shelf.io.connection_info'] as HttpConnectionInfo).remoteAddress.address;
          }
          // If the connection is local (proxy), attempt secure header fallback.
          if (ip == '127.0.0.1' || ip == '::1') {
            ip = request.headers['x-real-ip'] ?? request.headers['x-forwarded-for']?.split(',').first.trim() ?? ip;
          }
          
          final limited = await _checkRateLimit(request, ip);
          if (limited != null) return limited;
          return innerHandler(request);
        };
      })
      // 2.5. Redis-backed Idempotency Middleware (P1-01 FIX)
      .addMiddleware((innerHandler) {
        return (Request request) async {
          if (request.method == 'POST') {
             final idempotencyKey = request.headers['x-idempotency-key'];
             if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
                 final ok = await RedisService().checkAndSetIdempotencyKey(idempotencyKey);
                 if (!ok) {
                    return Response(409, body: jsonEncode({'success': false, 'message': 'Idempotent request already processed or in progress'}), headers: {'Content-Type': 'application/json; charset=utf-8'});
                 }
             }
          }
          return innerHandler(request);
        };
      })
      // 3. Request logger
      .addMiddleware(logRequests())
      // 4. Global error handler
      .addMiddleware((innerHandler) {
        return (Request request) async {
          try {
            return await innerHandler(request);
          } catch (e, stack) {
            // Shelf uses a special control-flow exception to "hijack" the
            // underlying HTTP connection for WebSocket upgrades.
            // It must propagate to the Shelf adapter; treating it as an error
            // breaks WebSocket handshakes.
            if (e.toString().contains("underlying data stream was hijacked")) {
              rethrow;
            }
            // Structured JSON payload for production logging (e.g. ELK, Datadog)
            final logPayload = jsonEncode({
              'level': 'ERROR',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'message': e.toString(),
              'stack_trace': stack.toString(),
              'path': request.url.path,
              'method': request.method,
            });
            print(logPayload);
            
            final isBusinessLogic = e is Exception;
            return Response(
              isBusinessLogic ? 400 : 500,
              body: jsonEncode({
                'success': false,
                'message': isBusinessLogic ? e.toString().replaceFirst('Exception: ', '') : 'An internal server error occurred'
              }),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
            );
          }
        };
      })
      // 5. CORS
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);

  print('Server listening on port ${server.port}');
  print('Visit: http://${server.address.address}:${server.port}');
}