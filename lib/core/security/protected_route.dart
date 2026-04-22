import 'package:flutter/material.dart';
import 'package:fs_hub/core/security/permission_guard.dart';

class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final String? routeName;
  final String requiredPermission;
  final List<String>? requiredPermissions;
  final String? requiredRole;
  final List<String>? requiredRoles;
  final Widget? fallback;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.routeName,
    this.requiredPermission = '',
    this.requiredPermissions,
    this.requiredRole,
    this.requiredRoles,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    // Check if user has access
    final hasAccess = _checkAccess();

    if (hasAccess) {
      return child;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    });

    return fallback ?? const SizedBox.shrink();
  }

  bool _checkAccess() {
    if (routeName != null && routeName!.isNotEmpty) {
      return PermissionGuard.canAccessRoute(routeName!);
    }

    // Check role-based access
    if (requiredRole != null) {
      return PermissionGuard.hasRole(requiredRole!);
    }

    if (requiredRoles != null) {
      return PermissionGuard.hasAnyRole(requiredRoles!);
    }

    // Check permission-based access
    if (requiredPermission.isNotEmpty) {
      return PermissionGuard.hasPermission(requiredPermission);
    }

    if (requiredPermissions != null) {
      return PermissionGuard.hasAnyPermission(requiredPermissions!);
    }

    return true; // No restrictions
  }

  Widget _buildAccessDeniedWidget(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Accès Refusé',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vous n\'avez pas les permissions nécessaires pour accéder à cette page.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre rôle: ${PermissionGuard.currentRole}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                ),
                icon: const Icon(Icons.home),
                label: const Text('Retour à l\'accueil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PermissionBuilder extends StatelessWidget {
  final Widget child;
  final String requiredPermission;
  final List<String>? requiredPermissions;
  final String? requiredRole;
  final List<String>? requiredRoles;
  final Widget? fallback;

  const PermissionBuilder({
    super.key,
    required this.child,
    this.requiredPermission = '',
    this.requiredPermissions,
    this.requiredRole,
    this.requiredRoles,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final hasAccess = _checkAccess();

    if (hasAccess) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }

  bool _checkAccess() {
    // Check role-based access
    if (requiredRole != null) {
      return PermissionGuard.hasRole(requiredRole!);
    }

    if (requiredRoles != null) {
      return PermissionGuard.hasAnyRole(requiredRoles!);
    }

    // Check permission-based access
    if (requiredPermission.isNotEmpty) {
      return PermissionGuard.hasPermission(requiredPermission);
    }

    if (requiredPermissions != null) {
      return PermissionGuard.hasAnyPermission(requiredPermissions!);
    }

    return true; // No restrictions
  }
}

/// Extension method for easy permission checking
extension PermissionContext on BuildContext {
  bool hasPermission(String permission) => PermissionGuard.hasPermission(permission);
  
  bool hasRole(String role) => PermissionGuard.hasRole(role);
  
  bool canAccess(String route) => PermissionGuard.canAccessRoute(route);

  String get userRole => PermissionGuard.currentRole;
}
