import 'package:flutter/material.dart';
import 'package:fs_hub/core/security/permission_guard.dart';
import 'package:fs_hub/features/home/screens/home/home_page.dart';
import 'package:fs_hub/features/employees/screens/employees_list_page.dart';
import 'package:fs_hub/features/employees/screens/add_edit_employee_page.dart';
import 'package:fs_hub/features/demands/screens/demands_list_page.dart';
import 'package:fs_hub/features/chat/presentation/pages/conversation_list_page.dart';
import 'package:fs_hub/features/employees/screens/my_profile_page.dart';
import 'package:fs_hub/shared/models/employee_model.dart';

class ProtectedRouteMiddleware {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final routeName = settings.name;
    final arguments = settings.arguments;

    // Check if user can access this route
    if (!PermissionGuard.canAccessRoute(routeName ?? '')) {
      return MaterialPageRoute(
        builder: (context) => const AccessDeniedPage(),
        settings: RouteSettings(name: '/access-denied'),
      );
    }

    // Route mapping based on permissions
    switch (routeName) {
      case '/':
        return MaterialPageRoute(
          builder: (context) => const HomePage(),
          settings: settings,
        );
      
      case '/employees':
        return MaterialPageRoute(
          builder: (context) => const EmployeesListPage(),
          settings: settings,
        );
      
      case '/employees/add':
        return MaterialPageRoute(
          builder: (context) => const AddEditEmployeePage(),
          settings: settings,
        );
      
      case '/employees/edit':
        if (arguments != null) {
          return MaterialPageRoute(
            builder: (context) => AddEditEmployeePage(employee: arguments as Employee),
            settings: settings,
          );
        }
        break;
      
      case '/demands':
        return MaterialPageRoute(
          builder: (context) => const DemandsListPage(),
          settings: settings,
        );
      
      case '/chat':
        return MaterialPageRoute(
          builder: (context) => const ConversationListPage(),
          settings: settings,
        );
      
      case '/profile':
        return MaterialPageRoute(
          builder: (context) => const MyProfilePage(),
          settings: settings,
        );
      
      default:
        return MaterialPageRoute(
          builder: (context) => const NotFoundPage(),
          settings: settings,
        );
    }

    // Fallback route
    return MaterialPageRoute(
      builder: (context) => const NotFoundPage(),
      settings: settings,
    );
  }
}

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Accès Refusé',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vous n\'avez pas les permissions nécessaires pour accéder à cette page.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre rôle: ${PermissionGuard.currentRole}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                ),
                icon: const Icon(Icons.home),
                label: const Text('Retour à l\'accueil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Page Non Trouvée',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'La page que vous cherchez n\'existe pas ou n\'est pas accessible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                ),
                icon: const Icon(Icons.home),
                label: const Text('Retour à l\'accueil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
