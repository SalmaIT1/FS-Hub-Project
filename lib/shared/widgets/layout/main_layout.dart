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
        
        // If we have an initialRoute, find its index based on fixed mapping
        if (widget.initialRoute != null) {
          switch (widget.initialRoute) {
            case '/':
            case '/home':
              _currentIndex = indexHome;
              break;
            case '/my-tasks':
            case '/tasks':
              _currentIndex = indexTasks;
              break;
            case '/employees':
              _currentIndex = indexEmployees;
              break;
            case '/demands':
              _currentIndex = indexDemands;
              break;
            case '/chat':
              _currentIndex = indexChat;
              break;
            case '/profile':
              _currentIndex = indexProfile;
              break;
          }
        }
        
        // Ensure index is valid for our 5 pages
        if (_currentIndex >= _fixedPages.length) {
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
        children: _fixedPages,
      ),
      bottomNavigationBar: _navigationItems.isEmpty 
        ? null 
        : GlassNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped),
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
