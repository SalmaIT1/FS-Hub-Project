import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/auth/screens/login_screen.dart';
import 'package:fs_hub/features/home/screens/home/home_page.dart';
import 'package:fs_hub/features/employees/screens/employee_detail_page.dart';
import 'package:fs_hub/features/demands/screens/demand_detail_page.dart';
import 'package:fs_hub/features/employees/screens/employees_list_page.dart';
import 'package:fs_hub/features/notifications/screens/notification_center_screen.dart';
import 'package:fs_hub/features/demands/screens/demands_list_page.dart';
import 'package:fs_hub/features/employees/screens/add_edit_employee_page.dart';
import 'package:fs_hub/features/employees/screens/my_profile_page.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
// New chat architecture
import 'package:fs_hub/chat/data/chat_rest_client.dart';
import 'package:fs_hub/chat/data/chat_socket_client.dart';
import 'package:fs_hub/chat/data/upload_service.dart';
import 'package:fs_hub/chat/data/chat_repository.dart';
import 'package:fs_hub/chat/state/chat_controller.dart';
import 'package:fs_hub/chat/ui/conversation_list_page.dart' as new_chat;
import 'package:fs_hub/chat/ui/chat_thread_page.dart' as new_chat;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FS Hub',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      darkTheme: _buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const GlassLoginPage(),
        '/home': (context) => const HomePage(),
        '/employees': (context) => const EmployeesListPage(),
        '/notifications': (context) => const NotificationCenterPage(),
        '/chat': (context) => _buildChatProvider(
          child: const new_chat.ConversationListPage(),
        ),
        '/demands': (context) => const DemandsListPage(),
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
              appBar: AppBar(title: const Text('Create Demand')),
              body: const Center(child: Text('Create Demand page not implemented yet')),
            ),
          );
        } else if (settings.name == AppRoutes.demandDetail) {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args['demand'] != null) {
            return MaterialPageRoute(
              builder: (context) => DemandDetailPage(demand: args['demand']),
            );
          }
        } else if (settings.name == '/chat_thread') {
          final args = settings.arguments as Map<String, dynamic>?;
          String conversationId = '';
          if (args != null) {
            if (args['conversationId'] != null) conversationId = args['conversationId'].toString();
            else if (args['conversation'] is Map && args['conversation']['id'] != null) conversationId = args['conversation']['id'].toString();
          }
          return MaterialPageRoute(
            builder: (context) => _buildChatProvider(
              child: conversationId.isNotEmpty 
                ? new_chat.ChatThreadPage(conversationId: conversationId)
                : const new_chat.ConversationListPage(),
            ),
          );
        }
        
        return null;
      },
    );
  }

  static Widget _buildChatProvider({required Widget child}) {
    // Initialize chat services with token provider and proper URLs
    const apiBaseUrl = 'http://localhost:8080';
    const wsBaseUrl = 'ws://localhost:8080/ws';

    // Token provider gets JWT from AuthService
    Future<String> getToken() async {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token available');
      }
      return token;
    }

    final restClient = ChatRestClient(
      baseUrl: apiBaseUrl,
      tokenProvider: getToken,
    );
    
    final socketClient = ChatSocketClient(
      wsUrl: wsBaseUrl,
      tokenProvider: getToken,
    );
    
    final uploadService = UploadService(
      baseUrl: apiBaseUrl,
      tokenProvider: getToken,
    );
    
    final repository = ChatRepository(
      rest: restClient,
      socket: socketClient,
      uploads: uploadService,
    );
    
    final controller = ChatController(repository: repository);

    return MultiProvider(
      providers: [
        Provider<ChatRestClient>(create: (_) => restClient),
        Provider<ChatSocketClient>(create: (_) => socketClient),
        Provider<UploadService>(create: (_) => uploadService),
        Provider<ChatRepository>(create: (_) => repository),
        ChangeNotifierProvider<ChatController>(create: (_) => controller),
      ],
      child: child,
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF5F7FA),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF5F7FA),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFF5F7FA),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF888888),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC9A24D),
        brightness: Brightness.dark,
        background: const Color(0xFF0A0A0A),
        surface: const Color(0xFF1A1A1A),
        primary: const Color(0xFFC9A24D),
        onPrimary: const Color(0xFFF5F7FA),
        onSurface: const Color(0xFFF5F7FA),
        onBackground: const Color(0xFFF5F7FA),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Colors.black],
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
      appBar: AppBar(title: const Text('Reset Password')),
      body: const Center(
        child: Text('Reset Password Page - Implementation needed'),
      ),
    );
  }
}
