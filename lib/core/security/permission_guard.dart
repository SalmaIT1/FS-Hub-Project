import 'dart:async';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/features/auth/services/permission_service.dart';
import 'package:fs_hub/features/auth/services/role_service.dart';

class PermissionGuard {
  static List<String> _userPermissions = [];
  static String _userRole = '';
  static Map<String, dynamic> _userInfo = {};
  static Timer? _refreshTimer;

  static const List<String> _publicRoutes = [
    '/',
    '/home',
    '/profile',
    '/settings',
    '/notifications',
    '/login',
    '/reset-password',
    '/chat',
    '/chat_thread',
  ];

  static final Map<String, List<String>> _routePermissions = {
    // Home & Profile
    '/': [],
    '/home': [],
    '/profile': [],
    '/settings': [],
    '/notifications': [],

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

    // Clients
    '/clients': ['view_clients', 'manage_clients'],
    '/client/detail': ['view_clients', 'manage_clients'],
    '/client/add': ['manage_clients'],
    '/client/edit': ['manage_clients'],

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
    // Chat is unrestricted for all authenticated users
    // '/chat': ['send_messages', 'view_messages'],
    // '/chat_thread': ['send_messages', 'view_messages'],

    // HR Module
    '/hr': ['view_employees', 'manage_employees', 'manage_salaries', 'manage_leaves', 'manage_attendance', 'manage_remote_work', 'manage_bonuses'],
    '/hr/attendance': ['view_employees', 'manage_attendance'],
    '/hr/attendance/history': ['view_employees', 'manage_attendance', 'attendance.view', 'log_own_attendance'],
    '/hr/leaves': ['view_employees', 'manage_leaves', 'leave.request', 'submit_leave'],
    '/hr/remote-work': ['view_employees', 'manage_remote_work', 'submit_remote_work'],
    '/hr/salaries': ['view_employees', 'manage_salaries', 'view_own_salary'],
    '/hr/bonuses': ['view_employees', 'manage_bonuses', 'view_own_bonuses'],
    '/ai': ['view_ai_dashboard', 'view_statistics', 'manage_system'],
  };

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
        
        print('[AUTH-GUARD] User: ${user['username']}, Role: $_userRole');
        
        // Use permissions from user object if available (preferred)
        if (user['permissions'] != null && user['permissions'] is List) {
          _userPermissions = (user['permissions'] as List).cast<String>().toList();
          print('[AUTH-GUARD] Loaded permissions from user object: $_userPermissions');
        } else if (user['permissions'] != null && user['permissions'] is String) {
          // Fallback for comma-separated string (legacy)
          _userPermissions = (user['permissions'] as String).split(',').map((p) => p.trim()).toList();
          print('[AUTH-GUARD] Loaded permissions from string: $_userPermissions');
        } else {
          print('[AUTH-GUARD] No permissions found in user object, using deep fallback...');
          // Deep fallback: Get role permissions from DB
          // Note: This may fail with 403 if the current user can't manage roles
          try {
            final roles = await RoleService.getAllRoles();
            final userRole = roles.firstWhere(
              (role) => role['nom'].toString().toLowerCase() == _userRole.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            if (userRole.isNotEmpty) {
              final roleId = userRole['id'];
              if (roleId != null) {
                final permissions = await PermissionService.getPermissionsByRole(roleId);
                _userPermissions = permissions.map((p) => p['nom'] as String).toList();
              }
            }
          } catch (e) {
            print('[AUTH-GUARD] Deep fallback failed: $e');
          }
        }

        // Always ensure employees have self-service permissions regardless of which path loaded them
        if (_userRole == 'Employé') {
          const employeePerms = [
            'view_own_salary',
            'view_own_bonuses',
            'view_messages',
            'send_messages',
            'attendance.view',
            'log_own_attendance',
            'submit_leave',
            'submit_remote_work',
          ];
          final missing = employeePerms.where((p) => !_userPermissions.contains(p)).toList();
          if (missing.isNotEmpty) {
            _userPermissions.addAll(missing);
            print('[PermissionGuard] Added missing employee self-service perms: $missing');
          }
        }

        print('[PermissionGuard] Role: $_userRole');
        print('[PermissionGuard] Permissions: $_userPermissions');
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
    
    // Support both view_employees and employees.view notations during transition
    String alternative = permission.contains('_') 
      ? permission.split('_').reversed.join('.') 
      : permission.split('.').reversed.join('_');
      
    // SINGULAR/PLURAL HANDLER: Handle 'leave' vs 'leaves'
    if (alternative.contains('leave') && !alternative.contains('leaves')) {
      alternative = alternative.replaceFirst('leave', 'leaves');
    } else if (alternative.contains('leaves')) {
      // also check the singular version
      final alternativeSingular = alternative.replaceFirst('leaves', 'leave');
      if (_userPermissions.contains(alternativeSingular)) return true;
    }
      
    return _userPermissions.contains(permission) || _userPermissions.contains(alternative);
  }

  /// Check if user has any of the specified permissions
  static bool hasAnyPermission(List<String> permissions) {
    if (hasRole('Admin')) return true;
    return permissions.any((p) => hasPermission(p));
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

  static List<String>? getRequiredPermissionsForRoute(String route) {
    return _routePermissions[route];
  }

  static bool isPublicRoute(String route) {
    return _publicRoutes.contains(route);
  }

  /// Check if user can access a specific page/route
  static bool canAccessRoute(String route) {
    // Admin can access everything
    if (hasRole('Admin')) {
      return true;
    }

    // Check specific route permissions
    if (!_routePermissions.containsKey(route)) {
      return isPublicRoute(route);
    }

    final requiredPermissions = _routePermissions[route]!;
    if (requiredPermissions.isEmpty) {
      return true; // No specific permissions required for this route
    }

    return hasAnyPermission(requiredPermissions);
  }

  /// Filter accessible routes based on user permissions
  static List<String> getAccessibleRoutes(List<String> routes) {
    return routes.where((route) => canAccessRoute(route)).toList();
  }

  /// Get navigation items for the GlassNavBar
  static List<Map<String, dynamic>> getNavigationItems() {
    if (hasRole('Client')) {
      return [
        {
          'title': 'Portail',
          'route': '/',
          'icon': 'home',
          'permissions': [], 
        },
        {
          'title': 'Chat',
          'route': '/chat',
          'icon': 'chat',
          'permissions': [],
        },
        {
          'title': 'Profil',
          'route': '/profile',
          'icon': 'person',
          'permissions': [],
        },
        {
          'title': 'Reglages',
          'route': '/settings',
          'icon': 'settings',
          'permissions': [],
        },
      ];
    }

    final allItems = [
      {
        'title': 'Accueil',
        'route': '/',
        'icon': 'home',
        'permissions': [], 
      },
      {
        'title': 'Tasks',
        'route': '/tasks',
        'icon': 'assignment',
        'permissions': ['view_tasks'],
      },
      {
        'title': 'Employees',
        'route': '/employees',
        'icon': 'people',
        'permissions': ['view_employees'],
      },
      {
        'title': 'Demands',
        'route': '/demands',
        'icon': 'description',
        'permissions': ['view_demands'],
      },
      {
        'title': 'Chat',
        'route': '/chat',
        'icon': 'chat',
        'permissions': ['view_messages', 'send_messages'],
      },
      {
        'title': 'Profile',
        'route': '/profile',
        'icon': 'person',
        'permissions': [],
      },
      {
        'title': 'Settings',
        'route': '/settings',
        'icon': 'settings',
        'permissions': [],
      },
    ];

    return allItems.where((item) => canAccessRoute(item['route'] as String)).toList();
  }

  /// Dispose resources
  static void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Test-only: seed RBAC context without HTTP (unit / widget tests).
  static void seedForTest({
    required String role,
    required List<String> permissions,
    Map<String, dynamic>? userInfo,
  }) {
    _userRole = role;
    _userPermissions = List.from(permissions);
    _userInfo = userInfo ?? {'role': role, 'permissions': permissions};
  }

  /// Test-only: reset static guard state between tests.
  static void resetForTest() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _userPermissions = [];
    _userRole = '';
    _userInfo = {};
  }
}
