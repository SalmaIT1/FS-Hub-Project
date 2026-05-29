import 'dart:async';
import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:fs_hub_backend/app/http_app.dart';
import 'package:fs_hub_backend/core/services/data_integrity_service.dart';
import 'package:fs_hub_backend/core/services/redis_service.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';
import 'package:fs_hub_backend/features/chat/data/repositories/chat_repository.dart';
import 'package:fs_hub_backend/features/chat/presentation/websocket/websocket_server.dart';
import 'package:fs_hub_backend/features/email/domain/services/email_service.dart';
import 'package:fs_hub_backend/shared/database/migrations.dart';
import 'package:shelf/shelf_io.dart';

String? corsOrigin;

void main(List<String> args) async {
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
  corsOrigin = env['CORS_ALLOWED_ORIGIN']?.trim();
  if (corsOrigin != null && corsOrigin!.endsWith('/')) {
    corsOrigin = corsOrigin!.substring(0, corsOrigin!.length - 1);
  }
  print('[SERVER] CORS configured for: $corsOrigin');

  final uploadsDir = Directory('uploads');
  if (!await uploadsDir.exists()) {
    print('[STORAGE] Initializing uploads/ directory...');
    await uploadsDir.create(recursive: true);
  }

  AuthService.initSecret();
  EmailService.initialize();
  await Migrations.initializeDatabase();
  await RedisService().initialize();

  final wsServer = WebSocketServer();
  wsServer.startCleanupTimer();

  DataIntegrityService.startPeriodicCleanup();
  await DataIntegrityService.checkDeadlines();

  Timer.periodic(const Duration(hours: 24), (timer) async {
    print('[BACKGROUND] Starting scheduled cleanup of orphaned uploads...');
    final count = await ChatRepository().cleanupOrphanedUploads();
    print('[BACKGROUND] Cleanup completed. Removed $count orphan records.');
  });

  final httpApp = HttpApp(webSocketServer: wsServer);
  final handler = httpApp.createHandler(corsOrigin: corsOrigin);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);

  print('Server listening on port ${server.port}');
  print('Visit: http://${server.address.address}:${server.port}');
}
