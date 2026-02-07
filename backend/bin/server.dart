import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

import '../lib/routes/auth_routes.dart';
import '../lib/routes/demand_routes.dart';
import '../lib/routes/notification_routes.dart';
import '../lib/routes/employee_routes.dart';
import '../lib/routes/email_routes.dart';
import '../lib/routes/conversation_routes.dart';

// Import database initialization
import '../lib/database/db_migration.dart';

void main(List<String> args) async {
  // Initialize database with migrations (this handles environment loading)
  await DBMigration.initializeDatabase();

  // Create router
  final router = Router()
    ..mount('/auth/', AuthRoutes().router)
    ..mount('/demands/', DemandRoutes().router)
    ..mount('/notifications/', NotificationRoutes().router)
    ..mount('/employees/', EmployeeRoutes().router)
    ..mount('/email/', EmailRoutes().router)
    ..mount('/conversations/', ConversationRoutes().router);

  // Add CORS middleware
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
  };

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware((innerHandler) {
        return (Request request) async {
          // Handle preflight requests
          if (request.method == 'OPTIONS') {
            return Response.ok('', headers: corsHeaders);
          }
          
          final response = await innerHandler(request);
          return response.change(headers: corsHeaders);
        };
      })
      .addHandler(router);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  
  print('Server listening on port ${server.port}');
  print('Visit: http://${server.address.address}:${server.port}');
}