import 'package:flutter/material.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/reset_password_page.dart';
import '../pages/employees/employees_list_page.dart';
import '../pages/employees/add_edit_employee_page.dart';
import '../pages/employees/employee_detail_page.dart';
import '../models/employee.dart';
import '../pages/settings/settings_page.dart';
import '../pages/home/home_page.dart';
import '../main.dart';

class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String resetPassword = '/reset-password';
  static const String employees = '/employees';
  static const String addEmployee = '/employees/add';
  static const String editEmployee = '/employees/edit';
  static const String employeeDetail = '/employees/detail';
  static const String projects = '/projects';
  static const String tasks = '/tasks';
  static const String finance = '/finance';
  static const String clients = '/clients';
  static const String invoices = '/invoices';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String chat = '/chat';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const GlassLoginPage(),
        home: (context) => const MyHomePage(title: 'FS HUB'),
        resetPassword: (context) => const ResetPasswordPage(),
        employees: (context) => EmployeesListPage(key: UniqueKey()),
        addEmployee: (context) => const AddEditEmployeePage(),
        settings: (context) => const SettingsPage(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == editEmployee) {
      final employee = settings.arguments as Employee?;
      return MaterialPageRoute(
        builder: (context) => AddEditEmployeePage(employee: employee),
      );
    }
    
    if (settings.name == employeeDetail) {
      final employee = settings.arguments as Employee;
      return MaterialPageRoute(
        builder: (context) => EmployeeDetailPage(employee: employee),
      );
    }
    
    return null;
  }
}
