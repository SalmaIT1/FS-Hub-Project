import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/core/security/permission_guard.dart';
import '../fixtures/auth_fixtures.dart';

void main() {
  tearDown(PermissionGuard.resetForTest);

  group('PermissionGuard — navigation & RBAC', () {
    test('Admin can access finance routes', () {
      PermissionGuard.seedForTest(
        role: FlutterAuthFixtures.adminRole,
        permissions: FlutterAuthFixtures.adminPermissions,
      );
      expect(PermissionGuard.canAccessRoute('/finance'), isTrue);
      expect(PermissionGuard.canAccessRoute('/invoices'), isTrue);
    });

    test('employee cannot access admin routes', () {
      PermissionGuard.seedForTest(
        role: FlutterAuthFixtures.employeeRole,
        permissions: FlutterAuthFixtures.employeePermissions,
      );
      expect(PermissionGuard.canAccessRoute('/admin'), isFalse);
      expect(PermissionGuard.canAccessRoute('/roles'), isFalse);
    });

    test('employee can access my-tasks with execute_tasks', () {
      PermissionGuard.seedForTest(
        role: FlutterAuthFixtures.employeeRole,
        permissions: FlutterAuthFixtures.employeePermissions,
      );
      expect(PermissionGuard.canAccessRoute('/my-tasks'), isTrue);
    });

    test('hasPermission supports view_employees / employees.view alias', () {
      PermissionGuard.seedForTest(
        role: FlutterAuthFixtures.employeeRole,
        permissions: ['view_employees'],
      );
      expect(PermissionGuard.hasPermission('employees.view'), isTrue);
    });

    test('public routes accessible without permissions', () {
      PermissionGuard.seedForTest(
        role: FlutterAuthFixtures.employeeRole,
        permissions: [],
      );
      expect(PermissionGuard.canAccessRoute('/login'), isTrue);
      expect(PermissionGuard.canAccessRoute('/settings'), isTrue);
    });

    test('Client role gets reduced navigation', () {
      PermissionGuard.seedForTest(
        role: 'Client',
        permissions: [],
      );
      final items = PermissionGuard.getNavigationItems();
      expect(items.every((i) => i['route'] != '/employees'), isTrue);
    });
  });
}
