import 'dart:convert';
import 'package:test/test.dart';
import 'package:fs_hub_backend/core/middleware/permission_middleware.dart';
import '../../helpers/shelf_request_factory.dart';
import '../../fixtures/auth_fixtures.dart';

void main() {
  group('requirePermission — RBAC', () {
    test('returns 401 when user not authenticated', () async {
      final request = authenticatedRequest(userId: '');
      final response = await invokeMiddleware(
        requirePermission(AuthFixtures.manageUsers),
        request,
      );
      expect(response.statusCode, 401);
    });

    test('Admin bypasses permission check', () async {
      final request = authenticatedRequest(
        userId: AuthFixtures.adminUserId,
        userRole: AuthFixtures.adminRole,
        permissions: [],
      );
      final response = await invokeMiddleware(
        requirePermission(AuthFixtures.manageUsers),
        request,
      );
      expect(response.statusCode, 200);
    });

    test('employee without manage_users gets 403', () async {
      final request = authenticatedRequest(
        userId: AuthFixtures.employeeUserId,
        userRole: AuthFixtures.employeeRole,
        permissions: AuthFixtures.employeePermissions,
      );
      final response = await invokeMiddleware(
        requirePermission(AuthFixtures.manageUsers),
        request,
      );
      expect(response.statusCode, 403);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['message'], contains('manage_users'));
    });

    test('manager with manage_invoices passes', () async {
      final request = authenticatedRequest(
        userId: AuthFixtures.managerUserId,
        userRole: AuthFixtures.managerRole,
        permissions: AuthFixtures.managerPermissions,
      );
      final response = await invokeMiddleware(
        requirePermission(AuthFixtures.manageInvoices),
        request,
      );
      expect(response.statusCode, 200);
    });
  });

  group('requireRoleOrPermission — finance access', () {
    test('Comptable role allowed without explicit permission', () async {
      final request = authenticatedRequest(
        userRole: 'Comptable',
        permissions: [],
      );
      final response = await invokeMiddleware(
        requireRoleOrPermission(
          ['Admin', 'Comptable', 'Manager', 'Client'],
          ['view_financial_reports'],
        ),
        request,
      );
      expect(response.statusCode, 200);
    });

    test('employee denied finance routes', () async {
      final request = authenticatedRequest(
        userRole: 'Employé',
        permissions: ['view_projects'],
      );
      final response = await invokeMiddleware(
        requireRoleOrPermission(
          ['Admin', 'Comptable'],
          ['manage_invoices'],
        ),
        request,
      );
      expect(response.statusCode, 403);
    });
  });

  group('requireAnyPermission', () {
    test('passes when user has one of required permissions', () async {
      final request = authenticatedRequest(
        permissions: ['view_projects', 'execute_tasks'],
      );
      final response = await invokeMiddleware(
        requireAnyPermission(['manage_projects', 'view_projects']),
        request,
      );
      expect(response.statusCode, 200);
    });
  });

  group('requireAdmin', () {
    test('non-admin receives 403', () async {
      final request = authenticatedRequest(
        userRole: 'Manager',
        permissions: AuthFixtures.managerPermissions,
      );
      final response = await invokeMiddleware(requireAdmin(), request);
      expect(response.statusCode, 403);
    });
  });
}
