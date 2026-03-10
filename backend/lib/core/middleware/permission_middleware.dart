import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../features/auth/domain/services/auth_service.dart';
import 'auth_middleware.dart';

/// Middleware to enforce specific permissions for routes.
/// Must be placed AFTER [requireAuth] in the pipeline.
Middleware requirePermission(String permission) {
  return (innerHandler) {
    return (Request request) async {
      final userId = request.authUserId;
      final userRole = request.authUserRole;

      if (userId.isEmpty) {
        return Response(
          401,
          body: jsonEncode({'success': false, 'message': 'User not authenticated'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ── Admin Bypass ────────────────────────────────────────────────────────
      // Administrators are granted all permissions by default.
      if (userRole.toLowerCase() == 'admin' || request.isAdmin) {
        return innerHandler(request);
      }

      // Check if user has the required permission
      final permissions = request.authUserPermissions;
      final hasPermission = permissions.contains(permission);

      if (!hasPermission) {
        print('[RBAC] 403 Forbidden: User $userId lacks permission "$permission"');
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'message': 'Insufficient permissions. Required permission: $permission'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return innerHandler(request);
    };
  };
}

/// Middleware to enforce admin-level access.
Middleware requireAdmin() {
  return (innerHandler) {
    return (Request request) async {
      if (request.isAdmin) {
        return innerHandler(request);
      }

      return Response(
        403,
        body: jsonEncode({
          'success': false,
          'message': 'Admin access required'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    };
  };
}

/// Middleware to enforce role-based access with fallback to permissions.
Middleware requireRoleOrPermission(List<String> allowedRoles, List<String> allowedPermissions) {
  return (innerHandler) {
    return (Request request) async {
      final userRole = request.authUserRole;
      final permissions = request.authUserPermissions;

      // Check role-based access first (Includes Admin Bypass)
      if (request.isAdmin || allowedRoles.contains(userRole)) {
        return innerHandler(request);
      }

      // Check permission-based access
      final hasRequiredPermission = allowedPermissions.any((p) => permissions.contains(p));
      if (hasRequiredPermission) {
        return innerHandler(request);
      }

      return Response(
        403,
        body: jsonEncode({
          'success': false,
          'message': 'Access denied. Required roles: $allowedRoles or permissions: $allowedPermissions'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    };
  };
}
