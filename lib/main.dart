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
import 'package:fs_hub/features/finance/screens/finance_dashboard_page.dart';
import 'package:fs_hub/features/finance/screens/invoices_list_page.dart';
import 'package:fs_hub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'package:fs_hub/shared/widgets/layout/custom_title_bar.dart';
import 'package:fs_hub/shared/widgets/layout/main_layout.dart';

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
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    const apiBaseUrl = 'http://localhost:8080';
    const wsBaseUrl = 'ws://localhost:8080/ws';

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(),
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
          return MaterialApp(
            title: Translations.getText('app_title', 'en'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.glassLightTheme,
            darkTheme: AppTheme.glassDarkTheme,
            themeMode: currentMode,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const GlassLoginPage(),
              '/home': (context) => MainLayout(initialIndex: 0),
              '/employees': (context) => MainLayout(initialIndex: 1),
              '/demands': (context) => MainLayout(initialIndex: 2),
              '/chat': (context) => MainLayout(initialIndex: 3),
              '/profile': (context) => MainLayout(initialIndex: 4),
              '/clients': (context) => const ClientsListPage(),
              AppRoutes.departments: (context) => const DepartmentsPage(),
               AppRoutes.projects: (context) => const ProjectsListPage(),
              '/notifications': (context) => const NotificationCenterPage(),
              '/finance': (context) => const FinanceDashboardPage(),
              '/invoices': (context) => const InvoicesListPage(),
              AppRoutes.settings: (context) => const SettingsPage(),
              AppRoutes.myTasks: (context) => const MyTasksPage(),
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
                  builder: (context) => MainLayout(initialIndex: 2),
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


