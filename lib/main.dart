import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/auth/presentation/pages/login_page.dart';
import 'package:fs_hub/features/auth/presentation/pages/splash_page.dart';
import 'package:fs_hub/features/home/screens/home/home_page.dart';
import 'package:fs_hub/features/employees/screens/employee_detail_page.dart';
import 'package:fs_hub/features/demands/screens/demand_detail_page.dart';
import 'package:fs_hub/features/employees/screens/employees_list_page.dart';
import 'package:fs_hub/features/notifications/screens/notification_center_screen.dart';
import 'package:fs_hub/features/demands/screens/demands_list_page.dart';
import 'package:fs_hub/features/employees/screens/add_edit_employee_page.dart';
import 'package:fs_hub/features/employees/screens/my_profile_page.dart';
import 'package:fs_hub/features/clients/screens/clients_list_page.dart';
import 'package:fs_hub/features/clients/screens/client_detail_page.dart';
import 'package:fs_hub/features/clients/screens/client_form_page.dart';
import 'package:fs_hub/features/departments/screens/departments_page.dart';
import 'package:fs_hub/features/projects/screens/projects_list_page.dart';
import 'package:fs_hub/features/projects/screens/sprints_list_page.dart';
import 'package:fs_hub/features/projects/screens/project_detail_page.dart';
import 'package:fs_hub/features/projects/screens/my_tasks_page.dart';
import 'package:fs_hub/features/finance/screens/financial_dashboard_page.dart';
import 'package:fs_hub/features/finance/screens/credits_list_page.dart';
import 'package:fs_hub/features/finance/screens/expenses_list_page.dart';
import 'package:fs_hub/features/home/screens/reports/reports_page.dart';
import 'package:fs_hub/features/auth/presentation/pages/roles_permissions_page.dart';
import 'package:fs_hub/features/finance/screens/invoices_list_page.dart';
import 'package:fs_hub/features/hr/presentation/pages/hr_dashboard_page.dart';
import 'package:fs_hub/features/hr/presentation/pages/hr_attendance_page.dart';
import 'package:fs_hub/features/hr/presentation/pages/hr_leaves_page.dart';
import 'package:fs_hub/features/hr/presentation/pages/hr_remote_work_page.dart';
import 'package:fs_hub/features/hr/presentation/pages/hr_salaries_page.dart';
import 'package:fs_hub/features/hr/presentation/pages/hr_bonuses_page.dart';
import 'package:fs_hub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'package:fs_hub/shared/widgets/layout/custom_title_bar.dart';
import 'package:fs_hub/shared/widgets/layout/main_layout.dart';
import 'package:fs_hub/core/security/permission_guard.dart';
import 'package:fs_hub/core/security/protected_route.dart';

import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/pages/settings_page.dart';
import 'package:fs_hub/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:fs_hub/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:fs_hub/features/chat/data/datasources/upload_datasource.dart';
import 'package:fs_hub/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:fs_hub/features/chat/presentation/providers/chat_provider.dart';
import 'package:fs_hub/features/chat/presentation/pages/conversation_list_page.dart' as chat_ui;
import 'package:fs_hub/features/chat/presentation/pages/chat_thread_page.dart' as chat_ui;
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';
import 'package:fs_hub/core/localization/translations.dart';
import 'package:fs_hub/core/state/location_controller.dart';
import 'package:fs_hub/core/config/app_config.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr', null);
  await initializeDateFormatting('en', null);
  
  // Initialize permission guard
  await PermissionGuard.initialize();
  await AppTheme.init();
  
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'FS Hub',
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      // Set window icon — relative to the executable for native but for debug we set it here
      // For Windows native builds, the icon comes from the executable resource
      // But we can try to set it dynamically too
      try {
        await windowManager.setIcon('assets/images/logo.png');
      } catch (e) {
        debugPrint('Failed to set window icon: $e');
      }

      await windowManager.show();
      await windowManager.focus();
      _updateWindowTitleBar(AppTheme.themeNotifier.value);
    });
  }

  runApp(const MyApp());
}

void _updateWindowTitleBar(ThemeMode mode) async {
  if (kIsWeb || !Platform.isWindows) return;
  
  final isDark = mode == ThemeMode.dark || 
                (mode == ThemeMode.system && 
                 WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
                 
  // Set window title bar theme and background
  await windowManager.setBrightness(isDark ? Brightness.dark : Brightness.light);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String> getToken() async {
    final token = await AuthRemoteDatasource.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token available');
    }
    return token;
  }

  @override
  Widget build(BuildContext context) {
    // Initialize chat services at the root level so they persist across routes
    final apiBaseUrl = AppConfig.apiBaseUrl;
    final wsBaseUrl = AppConfig.wsBaseUrl;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(),
        ),
        ChangeNotifierProvider<LocationController>(
          create: (_) => LocationController(),
        ),
        Provider<ChatRemoteDatasource>(
          create: (_) => ChatRemoteDatasource(baseUrl: apiBaseUrl, tokenProvider: () => getToken()),
        ),
        Provider<ChatSocketDatasource>(
          create: (_) => ChatSocketDatasource(wsUrl: wsBaseUrl, tokenProvider: () => getToken()),
        ),
        Provider<UploadDatasource>(
          create: (_) => UploadDatasource(baseUrl: apiBaseUrl, tokenProvider: () => getToken()),
        ),
        ProxyProvider3<ChatRemoteDatasource, ChatSocketDatasource, UploadDatasource, ChatRepositoryImpl>(
          update: (_, rest, socket, uploads, __) => ChatRepositoryImpl(rest: rest, socket: socket, uploads: uploads),
        ),
        ChangeNotifierProxyProvider<ChatRepositoryImpl, ChatController>(
          create: (context) => ChatController(
            repository: Provider.of<ChatRepositoryImpl>(context, listen: false),
          ),
          update: (_, repo, controller) => controller ?? ChatController(repository: repo),
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, currentMode, _) {
          _updateWindowTitleBar(currentMode);
          final settings = context.watch<SettingsController>();
          return MaterialApp(
            title: Translations.getText('app_title', settings.languageCode),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.glassLightTheme,
            darkTheme: AppTheme.glassDarkTheme,
            themeMode: currentMode,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const GlassLoginPage(),
              '/home': (context) => const MainLayout(initialRoute: '/'),
              '/employees': (context) => const MainLayout(initialRoute: '/employees'),
              '/demands': (context) => const MainLayout(initialRoute: '/demands'),
              '/chat': (context) => const MainLayout(initialRoute: '/chat'),
              '/profile': (context) => const MainLayout(initialRoute: '/profile'),
              AppRoutes.hrDashboard: (context) => ProtectedRoute(
                requiredPermissions: ['view_employees', 'manage_employees', 'manage_salaries', 'manage_leaves', 'manage_attendance', 'manage_remote_work', 'manage_bonuses'],
                child: const HrDashboardPage(),
              ),
              AppRoutes.hrAttendance: (context) => ProtectedRoute(
                requiredPermissions: ['view_employees', 'manage_attendance'],
                child: const HrAttendancePage(),
              ),
              AppRoutes.hrLeaves: (context) => ProtectedRoute(
                requiredPermissions: ['view_employees', 'manage_leaves'],
                child: const HrLeavesPage(),
              ),
              AppRoutes.hrRemoteWork: (context) => ProtectedRoute(
                requiredPermissions: ['view_employees', 'manage_remote_work'],
                child: const HrRemoteWorkPage(),
              ),
              AppRoutes.hrSalaries: (context) => ProtectedRoute(
                requiredPermissions: ['view_employees', 'manage_salaries'],
                child: const HrSalariesPage(),
              ),
              AppRoutes.hrBonuses: (context) => ProtectedRoute(
                requiredPermissions: ['view_employees', 'manage_bonuses'],
                child: const HrBonusesPage(),
              ),
              '/clients': (context) => const MainLayout(
                initialRoute: '/clients',
              ),
              AppRoutes.departments: (context) => ProtectedRoute(
                requiredPermissions: ['manage_system'],
                child: DepartmentsPage(),
              ),
              AppRoutes.projects: (context) => const MainLayout(initialRoute: '/projects'),
              '/notifications': (context) => const NotificationCenterPage(),
              '/finance': (context) => ProtectedRoute(
                requiredPermissions: ['view_financial_reports', 'view_revenue'],
                child: FinancialDashboardPage(),
              ),
              AppRoutes.credits: (context) => ProtectedRoute(
                requiredPermissions: ['manage_credits', 'view_financial_reports'],
                child: CreditsListPage(),
              ),
              AppRoutes.expenses: (context) => ProtectedRoute(
                requiredPermissions: ['manage_payments', 'view_financial_reports'],
                child: ExpensesListPage(),
              ),
              AppRoutes.roles: (context) => ProtectedRoute(
                requiredPermissions: ['manage_roles', 'manage_permissions'],
                child: RolesPermissionsPage(),
              ),
              AppRoutes.reports: (context) => ProtectedRoute(
                requiredPermissions: ['view_statistics', 'view_financial_reports'],
                child: ReportsPage(),
              ),
              '/invoices': (context) => ProtectedRoute(
                requiredPermissions: ['manage_invoices', 'view_financial_reports'],
                child: InvoicesListPage(),
              ),
              AppRoutes.settings: (context) => const SettingsPage(),
              AppRoutes.myTasks: (context) => ProtectedRoute(
                requiredPermissions: ['execute_tasks', 'view_tasks'],
                child: const MainLayout(initialRoute: '/my-tasks'),
              ),
            },
            onGenerateRoute: (settings) {
              // Handle routes with parameters
              if (settings.name == AppRoutes.employeeDetail) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['employee'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => EmployeeDetailPage(employee: args['employee']),
                  );
                }
              } else if (settings.name == AppRoutes.addEmployee) {
                return MaterialPageRoute(
                  builder: (context) => const AddEditEmployeePage(),
                );
              } else if (settings.name == AppRoutes.editEmployee) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['employee'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => AddEditEmployeePage(employee: args['employee']),
                  );
                }
              } else if (settings.name == AppRoutes.myProfile) {
                return MaterialPageRoute(
                  builder: (context) => const MyProfilePage(),
                );
              } else if (settings.name == AppRoutes.createDemand) {
                return MaterialPageRoute(
                  builder: (context) => const MainLayout(initialRoute: '/demands'),
                );
              } else if (settings.name == AppRoutes.demandDetail) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['demand'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => DemandDetailPage(demand: args['demand']),
                  );
                }
              } else if (settings.name == AppRoutes.clientDetail) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['client'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => ClientDetailPage(client: args['client']),
                  );
                }
              } else if (settings.name == AppRoutes.addClient) {
                return MaterialPageRoute(
                  builder: (context) => const ClientFormPage(),
                );
              } else if (settings.name == AppRoutes.editClient) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['client'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => ClientFormPage(client: args['client']),
                  );
                }
              } else if (settings.name == '/chat_thread') {
                final args = settings.arguments as Map<String, dynamic>?;
                String conversationId = '';
                ConversationEntity? conversation;
                if (args != null) {
                  if (args['conversationId'] != null) {
                    conversationId = args['conversationId'].toString();
                  } else if (args['conversation'] is Map && args['conversation']['id'] != null) {
                    conversationId = args['conversation']['id'].toString();
                  }
                  if (args['conversation'] is ConversationEntity) {
                    conversation = args['conversation'] as ConversationEntity;
                  }
                }

                return MaterialPageRoute(
                  builder: (context) => conversationId.isNotEmpty
                      ? chat_ui.ChatThreadPage(
                          conversationId: conversationId,
                          conversation: conversation,
                        )
                      : const chat_ui.ConversationListPage(),
                );
              } else if (settings.name == AppRoutes.sprints || settings.name == AppRoutes.projectDetail) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['project'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => ProjectDetailPage(project: args['project']),
                  );
                }
              }
              return null;
            },
            onUnknownRoute: (settings) => MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Page Not Found')),
                body: Center(
                  child: Text(
                    'No route defined for "${settings.name}"',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
            builder: (context, child) {
              if (kIsWeb || !Platform.isWindows) return child!;
              return CustomTitleBar(child: child!);
            },
          );
        },
      ),
    );
  }
}


