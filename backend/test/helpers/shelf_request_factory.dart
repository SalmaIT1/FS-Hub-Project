import 'package:shelf/shelf.dart';
import 'package:fs_hub_backend/core/middleware/auth_middleware.dart';

/// Builds authenticated Shelf requests for middleware unit tests.
Request authenticatedRequest({
  String method = 'GET',
  String path = '/v1/test',
  String userId = 'user-1',
  String userRole = 'Employé',
  List<String> permissions = const [],
  Map<String, String>? headers,
}) {
  final uri = Uri.parse('http://localhost$path');
  return Request(
    method,
    uri,
    headers: headers ?? {},
    context: {
      'userId': userId,
      'userRole': userRole,
      'userPermissions': permissions,
    },
  );
}

/// Runs [middleware] with a pre-authenticated request.
Future<Response> invokeMiddleware(
  Middleware middleware,
  Request request, {
  int successStatus = 200,
  String successBody = 'ok',
}) async {
  final handler = middleware((_) async => Response(successStatus, body: successBody));
  return handler(request);
}
