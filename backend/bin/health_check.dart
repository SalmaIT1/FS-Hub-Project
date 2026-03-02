import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  var handler = Pipeline().addMiddleware(logRequests()).addHandler((Request request) {
    return Response.ok('Hello from Dart backend (Health Check)!');
  });

  // Render sets the PORT environment variable automatically
  var port = int.parse(Platform.environment['PORT'] ?? '8080');
  
  // InternetAddress.anyIPv4 allows Render to connect to the service
  await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Health check server running on port $port');
}
