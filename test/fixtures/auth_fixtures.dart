/// RBAC fixtures for Flutter unit tests.
class FlutterAuthFixtures {
  FlutterAuthFixtures._();

  static const adminRole = 'Admin';
  static const managerRole = 'Manager';
  static const employeeRole = 'Employé';

  static const viewProjects = 'view_projects';
  static const manageProjects = 'manage_projects';
  static const manageInvoices = 'manage_invoices';
  static const viewFinancialReports = 'view_financial_reports';

  static List<String> adminPermissions = [
    viewProjects,
    manageProjects,
    manageInvoices,
    viewFinancialReports,
    'manage_users',
    'manage_roles',
  ];

  static List<String> employeePermissions = [
    viewProjects,
    'execute_tasks',
    'submit_leave',
  ];
}
