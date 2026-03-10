import 'dart:async';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/features/auth/services/permission_service.dart';
import 'package:fs_hub/features/auth/services/role_service.dart';

class PermissionGuard {
  static List<String> _userPermissions = [];
  static String _userRole = '';
  static Map<String, dynamic> _userInfo = {};
  static Timer? _refreshTimer;

  /// Initialize the permission guard with current user permissions
  static Future<void> initialize() async {
    await _loadUserPermissions();
    _startAutoRefresh();
  }

  /// Load current user permissions from backend
  static Future<void> _loadUserPermissions() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        _userInfo = user;
        _userRole = user['role'] ?? '';
        
        // Use permissions from user object if available (preferred)
        if (user['permissions'] != null && user['permissions'] is List) {
          _userPermissions = (user['permissions'] as List).cast<String>().toList();
          return;
        }

        // Fallback for comma-separated string (legacy)
        if (user['permissions'] != null && user['permissions'] is String) {
          _userPermissions = (user['permissions'] as String).split(',').map((p) => p.trim()).toList();
          return;
        }

        // Deep fallback: Get role permissions from DB
        // Note: This may fail with 403 if the current user can't manage roles
        final roles = await RoleService.getAllRoles();
        final userRole = roles.firstWhere(
          (role) => role['nom'] == _userRole,
          orElse: () => <String, dynamic>{},
        );
        
        if (userRole.isNotEmpty) {
          final roleId = userRole['id'];
          if (roleId != null) {
            final permissions = await PermissionService.getPermissionsByRole(roleId);
            _userPermissions = permissions.map((p) => p['nom'] as String).toList();
          }
        }
      }
    } catch (e) {
      print('Error loading user permissions: $e');
      // Don't clear if already have some (keep previous state during refresh failure)
      if (_userPermissions.isEmpty) {
        _userPermissions = [];
      }
    }
  }

  /// Start periodic refresh of permissions
  static void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadUserPermissions();
    });
  }

  /// Check if user has specific permission
  static bool hasPermission(String permission) {
    if (hasRole('Admin')) return true;
    return _userPermissions.contains(permission);
  }

  /// Check if user has any of the specified permissions
  static bool hasAnyPermission(List<String> permissions) {
    if (hasRole('Admin')) return true;
    return permissions.any((permission) => _userPermissions.contains(permission));
  }

  /// Check if user has all specified permissions
  static bool hasAllPermissions(List<String> permissions) {
    if (hasRole('Admin')) return true;
    return permissions.every((permission) => _userPermissions.contains(permission));
  }

  /// Check if user has specific role
  static bool hasRole(String role) {
    return _userRole.toLowerCase() == role.toLowerCase();
  }

  /// Check if user has any of the specified roles
  static bool hasAnyRole(List<String> roles) {
    final lowerUserRole = _userRole.toLowerCase();
    return roles.any((role) => role.toLowerCase() == lowerUserRole);
  }

  /// Get current user role
  static String get currentRole => _userRole;

  /// Get current user permissions
  static List<String> get currentPermissions => List.from(_userPermissions);

  /// Get current user info
  static Map<String, dynamic> get userInfo => Map.from(_userInfo);

  /// Check if user can access a specific page/route
  static bool canAccessRoute(String route) {
    // Define route permissions mapping
    final Map<String, List<String>> routePermissions = {
      // Home & Profile
      '/': [],
      '/home': [],
      '/profile': [],
      '/settings': [],
      
      // Employees
      '/employees': ['view_employees', 'manage_employees'],
      '/employee/add': ['manage_employees'],
      '/employee/edit': ['manage_employees'],
      '/employee/detail': ['view_employees'],
      
      // Projects
      '/projects': ['view_projects', 'manage_projects'],
      '/project/add': ['manage_projects'],
      '/project/edit': ['manage_projects'],
      '/project/detail': ['view_projects'],
      '/projects/sprints': ['view_projects'],
      
      // Tasks
      '/tasks': ['view_tasks', 'manage_tasks'],
      '/my-tasks': ['execute_tasks', 'view_tasks'],
      
      // Demands
      '/demands': ['view_demands', 'manage_demands'],
      '/demand/create': ['manage_demands'],
      '/demand-detail': ['view_demands'],
      
      // Finance
      '/finance': ['view_financial_reports', 'view_revenue'],
      '/expenses': ['manage_payments', 'view_financial_reports'],
      '/credits': ['manage_credits', 'view_financial_reports'],
      '/invoices': ['manage_invoices', 'view_financial_reports'],
      
      // Administration & Roles
      '/roles': ['manage_roles', 'manage_permissions'],
      '/departments': ['manage_employees', 'manage_system'],
      '/admin': ['manage_system', 'manage_users', 'manage_roles'],
      '/admin/users': ['manage_users'],
      '/admin/roles': ['manage_roles'],
      '/admin/permissions': ['manage_permissions'],
      
      // Reports & Statistics
      '/reports': ['view_statistics', 'view_financial_reports'],
      
      // Communication
      '/chat': ['send_messages', 'view_messages'],
      '/notifications': [],
      
      // HR Module
      '/hr': ['view_employees', 'manage_employees', 'manage_salaries', 'manage_leaves', 'manage_attendance', 'manage_remote_work', 'manage_bonuses'],
      '/hr/attendance': ['view_employees', 'manage_attendance'],
      '/hr/leaves': ['view_employees', 'manage_leaves'],
      '/hr/remote-work': ['view_employees', 'manage_remote_work'],
      '/hr/salaries': ['view_employees', 'manage_salaries'],
      '/hr/bonuses': ['view_employees', 'manage_bonuses'],
    };

    // Admin can access everything
    if (hasRole('Admin')) {
      return true;
    }

    // Check specific route permissions
    if (!routePermissions.containsKey(route)) {
      // For any route not explicitly in the map:
      // If it's a known public-ish route, allow. Otherwise, deny.
      final publicRoutes = ['/', '/home', '/profile', '/settings', '/notifications', '/login'];
      return publicRoutes.contains(route);
    }

    final requiredPermissions = routePermissions[route]!;
    if (requiredPermissions.isEmpty) {
      return true; // No specific permissions required for this route
    }

    return hasAnyPermission(requiredPermissions);
  }

  /// Filter accessible routes based on user permissions
  static List<String> getAccessibleRoutes(List<String> routes) {
    return routes.where((route) => canAccessRoute(route)).toList();
  }

  /// Get navigation items based on user role
  static List<Map<String, dynamic>> getNavigationItems() {
    final allItems = [
      {
        'title': 'Accueil',
        'route': '/',
        'icon': 'home',
        'permissions': [], // Everyone can access home
      },
      {
        'title': 'Employés',
        'route': '/employees',
        'icon': 'people',
        'permissions': ['view_employees', 'manage_employees'],
      },
      {
        'title': 'Projets',
        'route': '/projects',
        'icon': 'work',
        'permissions': ['view_projects', 'manage_projects'],
      },
      {
        'title': 'Tâches',
        'route': '/tasks',
        'icon': 'assignment',
        'permissions': ['view_tasks', 'manage_tasks'],
      },
      {
        'title': 'Demandes',
        'route': '/demands',
        'icon': 'description',
        'permissions': ['view_demands', 'manage_demands'],
      },
      {
        'title': 'Clients',
        'route': '/clients',
        'icon': 'business_center',
        'permissions': ['view_clients', 'manage_clients'],
      },
      {
        'title': 'Finance',
        'route': '/finance',
        'icon': 'account_balance',
        'permissions': ['view_financial_reports', 'view_revenue'],
      },
      {
        'title': 'Administration',
        'route': '/roles',
        'icon': 'settings',
        'permissions': ['manage_roles', 'manage_permissions', 'manage_system'],
      },
      {
        'title': 'Rapports',
        'route': '/reports',
        'icon': 'bar_chart',
        'permissions': ['view_statistics', 'view_financial_reports'],
      },
      {
        'title': 'Chat',
        'route': '/chat',
        'icon': 'chat',
        'permissions': ['view_messages', 'send_messages'],
      },
      {
        'title': 'Profil',
        'route': '/profile',
        'icon': 'person',
        'permissions': [], // Everyone can access their profile
      },
      {
        'title': 'RH',
        'route': '/hr',
        'icon': 'assignment_ind',
        'permissions': ['view_employees', 'manage_employees', 'manage_salaries', 'manage_leaves', 'manage_attendance', 'manage_remote_work', 'manage_bonuses'],
      },
    ];

    // Admin can see everything
    if (hasRole('Admin')) {
      return allItems;
    }

    // Filter items based on permissions
    return allItems.where((item) {
      final permissions = (item['permissions'] as List).cast<String>().toList();
      if (permissions.isEmpty) {
        return true; // Public item
      }
      return hasAnyPermission(permissions);
    }).toList();
  }

  /// Dispose resources
  static void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
