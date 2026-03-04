import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../features/auth/domain/services/auth_service.dart';

/// Global authentication middleware.
///
/// Verifies the Bearer token from the Authorization header and attaches
/// `userId` and `userRole` to the request context so that all downstream
/// handlers can retrieve them without repeating the auth logic.
///
/// Usage (per-router):
///   final securedRouter = Pipeline()
///       .addMiddleware(requireAuth())
///       .addHandler(SomeRoutes().router);
Middleware requireAuth() {
  return (innerHandler) {
    return (Request request) async {
      // OPTIONS pre-flight: let through without auth.
      if (request.method == 'OPTIONS') return innerHandler(request);

      final authHeader =
          request.headers['authorization'] ?? request.headers['Authorization'];

      String? token;
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        token = authHeader.split(' ').last;
      } else if (request.url.queryParameters.containsKey('token')) {
        token = request.url.queryParameters['token'];
      }

      if (token == null) {
        print('[AUTH] 401 missing/invalid Authorization header or token param for ${request.method} ${request.requestedUri.path}');
        return Response(
          401,
          body: jsonEncode(
              {'success': false, 'message': 'Authorization required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Check if token has been invalidated (logged out).
      if (AuthService.isTokenRevoked(token)) {
        print('[AUTH] 401 revoked token for ${request.method} ${request.requestedUri.path}');
        return Response(
          401,
          body: jsonEncode({'success': false, 'message': 'Token revoked'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        print('[AUTH] 401 invalid/expired token for ${request.method} ${request.requestedUri.path}');
        return Response(
          401,
          body: jsonEncode(
              {'success': false, 'message': 'Invalid or expired token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userId = payload['userId']?.toString() ?? '';
      final userRole = payload['role']?.toString() ?? 'Employé';

      if (userId.isEmpty) {
        return Response(
          401,
          body: jsonEncode({'success': false, 'message': 'Invalid token payload'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Attach identity to context for downstream handlers.
      final updatedRequest = request.change(context: {
        ...request.context,
        'userId': userId,
        'userRole': userRole,
      });

      return innerHandler(updatedRequest);
    };
  };
}

/// Middleware to enforce specific roles for a group of routes.
/// Must be placed AFTER [requireAuth] in the pipeline.
Middleware requireRole(List<String> allowedRoles) {
  return (innerHandler) {
    return (Request request) async {
      final userRole = request.context['userRole'] as String? ?? 'Employé';

      if (!allowedRoles.contains(userRole)) {
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'message': 'Insufficient permissions. Required roles: $allowedRoles'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return innerHandler(request);
    };
  };
}

/// Convenience extension: retrieve the authenticated user's ID from context.
extension AuthContext on Request {
  String get authUserId => context['userId'] as String? ?? '';
  String get authUserRole => context['userRole'] as String? ?? 'Employé';
  bool get isAdmin => authUserRole == 'Admin';
  bool get isRH => authUserRole == 'RH' || authUserRole == 'Admin';
}
