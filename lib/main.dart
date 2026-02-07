import 'package:flutter/material.dart';
import 'package:fs_hub/pages/auth/login_page.dart';
import 'package:fs_hub/pages/home/home_page.dart';
import 'package:fs_hub/pages/employees/employees_list_page.dart';
import 'package:fs_hub/pages/employees/employee_detail_page.dart';
import 'package:fs_hub/pages/employees/add_edit_employee_page.dart';
import 'package:fs_hub/pages/employees/my_profile_page.dart';
import 'package:fs_hub/pages/notifications/notification_center_page.dart';
import 'package:fs_hub/pages/chat/chat_page.dart';
import 'package:fs_hub/pages/demands/demands_list_page.dart';
import 'package:fs_hub/pages/demands/demand_detail_page.dart';
import 'package:fs_hub/pages/settings/settings_page.dart';
import 'package:fs_hub/routes/app_routes.dart';
import 'package:fs_hub/services/auth_service.dart';
import 'package:fs_hub/theme/app_theme.dart';

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
        '/chat': (context) => const ChatPage(),
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
        }
        
        return null;
      },
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
