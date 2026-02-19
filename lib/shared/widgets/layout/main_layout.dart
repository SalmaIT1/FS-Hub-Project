import 'package:flutter/material.dart';
import '../navigation/glass_nav_bar.dart';
import '../../../features/home/screens/home/home_page.dart';
import '../../../features/employees/screens/employees_list_page.dart';
import '../../../features/demands/screens/demands_list_page.dart';
import '../../../chat/ui/conversation_list_page.dart';
import '../../../features/employees/screens/my_profile_page.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  
  const MainLayout({
    Key? key,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  
  final List<Widget> _pages = [
    const HomePage(),
    const EmployeesListPage(),
    const DemandsListPage(),
    const ConversationListPage(),
    const MyProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
      extendBody: true, // This allows the body to go behind the bottom navigation bar
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: GlassNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
