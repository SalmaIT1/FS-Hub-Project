import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

import '../lib/routes/auth_routes.dart';
import '../lib/routes/demand_routes.dart';
import '../lib/routes/notification_routes.dart';
import '../lib/routes/employee_routes.dart';
import '../lib/routes/email_routes.dart';
import '../lib/routes/conversation_routes.dart';
import '../lib/routes/upload_routes.dart';
import '../lib/routes/media_routes.dart';
import '../lib/routes/enhanced_media_routes.dart';
import '../lib/routes/voice_routes.dart';
import '../lib/modules/chat/websocket_server.dart';
import '../lib/services/data_integrity_service.dart';

// Import database initialization
import '../lib/database/db_migration.dart';

void main(List<String> args) async {
  // Initialize database with migrations (this handles environment loading)
  await DBMigration.initializeDatabase();

  // Initialize WebSocket server
  final wsServer = WebSocketServer();
  wsServer.startCleanupTimer();

  // Start data integrity service
  DataIntegrityService.startPeriodicCleanup();

  // Create router with versioned API paths
  final router = Router()
    ..mount('/v1/auth', AuthRoutes().router)
    ..mount('/v1/demands', DemandRoutes().router)
    ..mount('/v1/notifications', NotificationRoutes().router)
    ..mount('/v1/employees', EmployeeRoutes().router)
    ..mount('/v1/email', EmailRoutes().router)
    ..mount('/v1/conversations', ConversationRoutes().router)
    ..mount('/v1/uploads', UploadRoutes().router)
    // Redirect legacy /media/voice.wav requests to /voice/voice.wav (must be before /media mount)
    ..get('/media/<filename|.*\\.wav>', (Request req, String filename) {
      return Response.movedPermanently('/voice/$filename');
    })
    ..mount('/media', EnhancedMediaRoutes().router)
    ..mount('/api/voice', VoiceRoutes().router)
    ..mount('/voice', VoiceRoutes().router)
    ..mount('/ws', wsServer.router);

  // Add CORS middleware
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
    'Access-Control-Allow-Private-Network': 'true', // For WebSocket on localhost
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