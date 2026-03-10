import 'package:flutter/material.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';

/// A widget that only displays its child if the user has the required permission.
class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.hasPermission(permission),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// A widget that only displays its child if the user has the required role.
class RoleGuard extends StatelessWidget {
  final String role;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.role,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.hasRole(role),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
