import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/auth/screens/login_screen.dart';
import 'package:fs_hub/features/auth/screens/splash_screen.dart';
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
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'package:fs_hub/shared/widgets/layout/main_layout.dart';

import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/pages/settings_page.dart';
import 'package:fs_hub/chat/data/chat_rest_client.dart';
import 'package:fs_hub/chat/data/chat_socket_client.dart';
import 'package:fs_hub/chat/data/upload_service.dart';
import 'package:fs_hub/chat/data/chat_repository.dart';
import 'package:fs_hub/chat/state/chat_controller.dart';
import 'package:fs_hub/features/chat/ui/conversation_list_page.dart' as chat_ui;
import 'package:fs_hub/features/chat/ui/chat_thread_page.dart' as chat_ui;
import 'package:fs_hub/chat/domain/chat_entities.dart';
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
      titleBarStyle: TitleBarStyle.normal,
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
    final token = await AuthService.getAccessToken();
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
        Provider<ChatRestClient>(
          create: (_) => ChatRestClient(baseUrl: apiBaseUrl, tokenProvider: () => getToken()),
        ),
        Provider<ChatSocketClient>(
          create: (_) => ChatSocketClient(wsUrl: wsBaseUrl, tokenProvider: () => getToken()),
        ),
        Provider<UploadService>(
          create: (_) => UploadService(baseUrl: apiBaseUrl, tokenProvider: () => getToken()),
        ),
        ProxyProvider3<ChatRestClient, ChatSocketClient, UploadService, ChatRepository>(
          update: (_, rest, socket, uploads, __) => ChatRepository(rest: rest, socket: socket, uploads: uploads),
        ),
        ChangeNotifierProxyProvider<ChatRepository, ChatController>(
          create: (context) => ChatController(
            repository: Provider.of<ChatRepository>(context, listen: false),
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
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: Text(Translations.getText('create_demand', 'en')),
                      automaticallyImplyLeading: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    body: Center(child: Text(Translations.getText('reset_password_page_subtitle', 'en'))),
                  ),
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
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 3)); // 3 seconds splash screen delay

    final isLoggedIn = await AuthService.isLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF1A1A1A), Colors.black]
              : [const Color(0xFFF5F7FA), Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Signature image
              Image.asset(
                'assets/images/signature.jpeg',
                height: 200,
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText('reset_password_page', 'en')),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text(Translations.getText('reset_password_page_subtitle', 'en')),
      ),
    );
  }
}
