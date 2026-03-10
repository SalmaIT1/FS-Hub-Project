import 'dart:convert';
import 'dart:io';
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

import 'package:fs_hub_backend/features/email/domain/services/email_service.dart';
import 'package:fs_hub_backend/features/employees/presentation/routes/poste_routes.dart';
import 'package:fs_hub_backend/features/chat/presentation/websocket/websocket_server.dart';
import 'package:fs_hub_backend/core/services/data_integrity_service.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';
import 'package:fs_hub_backend/core/middleware/auth_middleware.dart';
import 'package:fs_hub_backend/core/middleware/permission_middleware.dart';

// Import database initialization
import 'package:fs_hub_backend/shared/database/migrations.dart';

void main(List<String> args) async {
  // Initialize JWT secret FIRST — throws if missing.
  AuthService.initSecret();
  
  // Initialize Email service to load SMTP settings.
  EmailService.initialize();

  // Initialize database with migrations.
  await Migrations.initializeDatabase();

  // Initialize WebSocket server.
  final wsServer = WebSocketServer();
  wsServer.startCleanupTimer();

  // Start data integrity service.
  DataIntegrityService.startPeriodicCleanup();

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
      Pipeline().addMiddleware(requireAuth()).addMiddleware(requireRoleOrPermission(['Admin', 'Comptable', 'Manager'], ['manage_finance', 'view_finances'])).addHandler(r.call);

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
    ..get('/health', (Request request) => Response.ok('OK'));

  // CORS middleware — dynamically allows localhost origins only.
  Map<String, String> corsHeaders(Request request) {
    final origin = request.headers['origin'] ?? '';
    // Allow any localhost origin (any port) in dev mode.
    final isAllowed = origin.startsWith('http://localhost') ||
        origin.startsWith('https://localhost') ||
        origin.startsWith('http://127.0.0.1') ||
        origin.contains('.ngrok-free.app') ||
        origin.contains('.ngrok.io') ||
        origin.isEmpty; // same-origin requests may omit Origin
    return {
      'Access-Control-Allow-Origin': isAllowed && origin.isNotEmpty ? origin : 'http://localhost',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers':
          'Origin, Content-Type, Accept, Authorization, X-User-Id',
      'Access-Control-Allow-Private-Network': 'true',
    };
  }

  // 1. Global Request Body Size Limit (2MB for standard requests)
  // 2. Simple Rate Limiter (Login protection)
  final loginAttempts = <String, List<DateTime>>{};

  final handler = Pipeline()
      .addMiddleware((innerHandler) {
        return (Request request) async {
          // Skip size check for the actual upload PUT endpoint
          if (request.url.path.contains('/v1/uploads/') && request.method == 'PUT') {
            return innerHandler(request);
          }
          
          final contentLength = int.tryParse(request.headers['content-length'] ?? '0') ?? 0;
          if (contentLength > 2 * 1024 * 1024) { // 2MB cap
            return Response(413, body: jsonEncode({'success': false, 'message': 'Request body too large'}), headers: {'Content-Type': 'application/json'});
          }
          return innerHandler(request);
        };
      })
      .addMiddleware((innerHandler) {
        return (Request request) async {
          final path = request.url.path.replaceAll(RegExp(r'^\/'), '');
          if (path == 'v1/auth/login' && request.method == 'POST') {
            final ip = request.context['shelf.io.connection_info'] != null 
                ? (request.context['shelf.io.connection_info'] as HttpConnectionInfo).remoteAddress.address 
                : 'unknown';
            
            final now = DateTime.now();
            final attempts = loginAttempts.putIfAbsent(ip, () => []);
            attempts.removeWhere((d) => now.difference(d).inMinutes > 5);
            
            if (attempts.length > 10) { // 10 attempts per 5 minutes
              return Response(429, body: jsonEncode({'success': false, 'message': 'Too many login attempts. Please wait 5 minutes.'}), headers: {'Content-Type': 'application/json'});
            }
            attempts.add(now);
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
            // Shelf uses a special control-flow exception to "hijack" the
            // underlying HTTP connection for WebSocket upgrades.
            // It must propagate to the Shelf adapter; treating it as an error
            // breaks WebSocket handshakes.
            if (e.toString().contains("underlying data stream was hijacked")) {
              rethrow;
            }
            print('🔥 GLOBAL ERROR: $e\n$stack');
            return Response.internalServerError(
              body: jsonEncode({
                'success': false,
                'message': 'An internal server error occurred'
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        };
      })
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
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);

  print('Server listening on port ${server.port}');
  print('Visit: http://${server.address.address}:${server.port}');
}