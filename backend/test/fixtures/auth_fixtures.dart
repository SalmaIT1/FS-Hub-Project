/// Fake users and RBAC fixtures for FS-Hub backend tests.
class AuthFixtures {
  AuthFixtures._();

  static const adminUserId = 'admin-uuid-001';
  static const managerUserId = 'manager-uuid-002';
  static const employeeUserId = 'employee-uuid-003';

  static const adminRole = 'Admin';
  static const managerRole = 'Manager';
  static const employeeRole = 'Employé';

  static const manageUsers = 'manage_users';
  static const manageRoles = 'manage_roles';
  static const manageInvoices = 'manage_invoices';
  static const viewProjects = 'view_projects';
  static const manageLeaves = 'manage_leaves';

  static List<String> adminPermissions = [
    manageUsers,
    manageRoles,
    manageInvoices,
    viewProjects,
    manageLeaves,
  ];

  static List<String> managerPermissions = [
    viewProjects,
    manageInvoices,
    manageLeaves,
  ];

  static List<String> employeePermissions = [
    viewProjects,
  ];

  static Map<String, dynamic> adminJwtPayload = {
    'userId': adminUserId,
    'role': adminRole,
  };

  static Map<String, dynamic> employeeJwtPayload = {
    'userId': employeeUserId,
    'role': employeeRole,
  };
}
