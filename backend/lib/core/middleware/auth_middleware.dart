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
/// Global cache for user permissions to prevent redundant DB hits.
final Map<String, _PermissionCacheEntry> _permissionCache = {};
const int _maxCacheSize = 1000;

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
      } else {
        // P3 FIX: Support 'token' query parameter for browser-level access (media/downloads)
        token = request.requestedUri.queryParameters['token'];
      }

      if (token == null) {
        print('[AUTH] 401 missing/invalid Authorization header for ${request.method} ${request.requestedUri.path}');
        return Response(
          401,
          body: jsonEncode(
              {'success': false, 'message': 'Authorization required'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      // Check if token has been invalidated (logged out).
      if (await AuthService.isTokenRevoked(token)) {
        return Response(
          401,
          body: jsonEncode({'success': false, 'message': 'Token revoked'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response(
          401,
          body: jsonEncode(
              {'success': false, 'message': 'Invalid or expired token'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final userId = payload['userId']?.toString() ?? '';
      final userRole = payload['role']?.toString() ?? 'Employé';

      if (userId.isEmpty) {
        return Response(
          401,
          body: jsonEncode({'success': false, 'message': 'Invalid token payload'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      // P2 FIX: Cache lookup
      List<String> permissions;
      final cached = _permissionCache[userId];
      if (cached != null && !cached.isExpired) {
        permissions = cached.permissions;
      } else {
        permissions = await AuthService.getUserPermissions(userId);
        
        // P0 FIX: Prevent map from growing unbounded.
        if (_permissionCache.length >= _maxCacheSize) {
          // Prune expired entries
          _permissionCache.removeWhere((key, value) => value.isExpired);
          // If still too large, clear all to reset
          if (_permissionCache.length >= _maxCacheSize) {
            _permissionCache.clear();
          }
        }
        
        _permissionCache[userId] = _PermissionCacheEntry(
          permissions: permissions,
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
      }

      final updatedRequest = request.change(context: {
        ...request.context,
        'userId': userId,
        'userRole': userRole,
        'userPermissions': permissions,
      });

      return innerHandler(updatedRequest);
    };
  };
}

class _PermissionCacheEntry {
  final List<String> permissions;
  final DateTime expiresAt;
  _PermissionCacheEntry({required this.permissions, required this.expiresAt});
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}


/// Middleware to enforce specific roles for a group of routes.
/// Must be placed AFTER [requireAuth] in the pipeline.

/// Middleware to enforce specific roles for a group of routes.
/// Must be placed AFTER [requireAuth] in the pipeline.
Middleware requireRole(List<String> allowedRoles) {
  return (innerHandler) {
    return (Request request) async {
      final userRole = request.authUserRole;

      if (!allowedRoles.contains(userRole)) {
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'message': 'Insufficient permissions. Required roles: $allowedRoles'
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      return innerHandler(request);
    };
  };
}

/// Middleware to enforce specific permissions for a route.
/// Must be placed AFTER [requireAuth] in the pipeline.
Middleware checkPermission(String permission) {
  return (innerHandler) {
    return (Request request) async {
      final permissions = request.authUserPermissions;

      if (!permissions.contains(permission)) {
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'message': 'Permission denied: $permission'
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
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
  List<String> get authUserPermissions {
    final perms = context['userPermissions'];
    if (perms is List<String>) return perms;
    if (perms is List) return perms.map((e) => e.toString()).toList().cast<String>();
    return [];
  }
  bool get isAdmin => authUserRole == 'Admin';
  bool get isRH => authUserRole == 'RH' || authUserRole == 'Admin';
  bool hasPermission(String perm) => authUserPermissions.contains(perm);
}
