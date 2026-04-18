import 'package:flutter/material.dart';
import '../navigation/glass_nav_bar.dart';
import '../../../features/home/screens/home/home_page.dart';
import '../../../features/employees/screens/employees_list_page.dart';
import '../../../features/demands/screens/demands_list_page.dart';
import '../../../features/chat/presentation/pages/conversation_list_page.dart';
import '../../../features/employees/screens/my_profile_page.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/security/protected_route.dart';
import '../../../features/projects/screens/my_tasks_page.dart';
import '../../../features/ai/presentation/pages/ai_dashboard_page.dart';
import '../../../../pages/settings_page.dart';

class MainLayout extends StatefulWidget {
  final String? initialRoute;
  final int initialIndex;
  
  const MainLayout({
    super.key,
    this.initialRoute,
    this.initialIndex = 0,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  List<Map<String, dynamic>> _navigationItems = [];
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    await PermissionGuard.initialize();
    await _loadNavigationItems();
  }
  

  // Fixed indices for navigation agreement with GlassNavBar
  static const int indexHome = 0;
  static const int indexTasks = 1;
  static const int indexEmployees = 2;
  static const int indexDemands = 3;
  static const int indexChat = 4;
  static const int indexProfile = 5;

  final List<Widget> _fixedPages = [
    const HomePage(),
    const MyTasksPage(),
    const EmployeesListPage(),
    const DemandsListPage(),
    const ConversationListPage(),
    const MyProfilePage(),
  ];

  Future<void> _loadNavigationItems() async {
    final items = PermissionGuard.getNavigationItems();
    if (mounted) {
      setState(() {
        _navigationItems = items;

        _pages = _navigationItems.map<Widget>((item) {
          final route = item['route'] as String?;
          switch (route) {
            case '/':
            case '/home':
              return const HomePage();
            case '/my-tasks':
            case '/tasks':
              return const MyTasksPage();
            case '/employees':
              return const EmployeesListPage();
            case '/demands':
              return const DemandsListPage();
            case '/chat':
              return const ConversationListPage();
            case '/profile':
              return const MyProfilePage();
            case '/ai':
              return const AiDashboardPage();
            case '/settings':
              return SettingsPage();
            default:
              return const HomePage();
          }
        }).toList();
        
        // If we have an initialRoute, find its index based on fixed mapping
        if (widget.initialRoute != null) {
          final idx = _navigationItems.indexWhere((i) => i['route'] == widget.initialRoute);
          if (idx >= 0) {
            _currentIndex = idx;
          } else {
            _currentIndex = 0;
          }
        }
        
        if (_pages.isEmpty) {
          _pages = [const HomePage()];
        }

        if (_currentIndex >= _pages.length) {
          _currentIndex = 0;
        }
      });
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages.isEmpty ? [const HomePage()] : _pages,
      ),
      bottomNavigationBar: _navigationItems.isEmpty 
        ? null 
        : GlassNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            items: _navigationItems,
          ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home_outlined;
      case 'people':
        return Icons.people_outline;
      case 'work':
        return Icons.work_outline;
      case 'assignment':
        return Icons.assignment_outlined;
      case 'description':
        return Icons.description_outlined;
      case 'account_balance':
        return Icons.account_balance_outlined;
      case 'people_outline':
        return Icons.people_outline;
      case 'settings':
        return Icons.settings_outlined;
      case 'bar_chart':
        return Icons.bar_chart_outlined;
      case 'chat':
        return Icons.chat_outlined;
      case 'person':
        return Icons.person_outline;
      case 'auto_awesome':
        return Icons.auto_awesome;
      default:
        return Icons.home_outlined;
    }
  }

  @override
  void dispose() {
    PermissionGuard.dispose();
    super.dispose();
  }
}
