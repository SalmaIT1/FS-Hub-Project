import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../employees/services/employee_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../navigation/chat_router.dart';

import 'package:provider/provider.dart';
import '../../../../core/state/settings_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _greetingName = 'User';
  int _pendingDemandsCount = 0;
  int _notificationCount = 0;
  String? _userRole;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await AuthService.getGreetingName();
    final user = await AuthService.getCurrentUser();
    
    if (mounted) {
      setState(() {
        _greetingName = name;
        _userRole = user?['role'];
        _userId = user?['id'];
      });
    }
    
    // Load dashboard data after user data is loaded
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load pending demands count
      final demandsResult = await EmployeeService.getAllDemands(status: 'pending');
      if (demandsResult['success']) {
        final List<dynamic> demands = demandsResult['data'];
        
        if (_userRole != 'Admin') {
          // For non-admins, only count their own pending demands
          final user = await AuthService.getCurrentUser();
          if (user != null) {
            final userId = user['id'];
            demands.removeWhere((demand) => demand['requesterId'] != userId);
          }
        }
        
        if (mounted) {
          setState(() {
            _pendingDemandsCount = demands.length;
          });
        }
      }
      
      // Load notification count
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser != null) {
        final userId = currentUser['id'];
        final notificationsResult = await EmployeeService.getUserNotifications(userId);
        if (notificationsResult['success']) {
          final List<dynamic> notifications = notificationsResult['data'];
          final unreadCount = notifications.where((n) => !n['isRead']).length;
          
          if (mounted) {
            setState(() {
              _notificationCount = unreadCount;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
  }

  String _getGreeting(SettingsController settings) {
    final hour = DateTime.now().hour;
    if (hour < 12) return settings.translate('good_morning');
    if (hour < 17) return settings.translate('good_afternoon');
    return settings.translate('good_evening');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'FS Hub',
        subtitle: '${_getGreeting(settings)}, ${_greetingName.isNotEmpty ? _greetingName : 'User'}',
        showBackButton: false,
        isPremium: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: isDark 
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth > 800) crossAxisCount = 4;
                if (constraints.maxWidth > 1200) crossAxisCount = 6;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Text(
                        settings.translate('ops_overview'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                        ),
                      ),
                    ),
                    // Primary modules (larger cards)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        GlassCard(
                          title: settings.translate('employees'),
                          caption: settings.languageCode == 'fr' ? 'Personnel' : 'Staff & Roles',
                          icon: Icons.badge_outlined,
                          onTap: () => Navigator.pushNamed(context, '/employees'),
                          isPrimary: true,
                        ),
                        GlassCard(
                          title: settings.translate('projects'),
                          caption: settings.languageCode == 'fr' ? 'Labos actifs' : 'Active Labs',
                          icon: Icons.biotech_outlined,
                          onTap: () => Navigator.pushNamed(context, '/demands'),
                          isPrimary: true,
                        ),
                        GlassCard(
                          title: settings.translate('demands'),
                          caption: settings.languageCode == 'fr' ? 'Requêtes' : 'Requests',
                          icon: Icons.assignment_outlined,
                          onTap: () => Navigator.pushNamed(context, '/demands'),
                          isPrimary: true,
                        ),
                        GlassCard(
                          title: settings.translate('finance'),
                          caption: settings.languageCode == 'fr' ? 'Capital & Rendement' : 'Capital & Yield',
                          icon: Icons.account_balance_outlined,
                          onTap: () => Navigator.pushNamed(context, '/notifications'),
                          isPrimary: true,
                        ),
                      ],
                    ),
                    // Secondary modules
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                      child: Text(
                        settings.translate('support_modules'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                          color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                        ),
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.0,
                      children: [
                        GlassCard(
                          title: settings.translate('tasks'),
                          caption: 'Pipeline',
                          icon: Icons.checklist_rtl_outlined,
                          onTap: () => Navigator.pushNamed(context, '/demands'),
                        ),
                        GlassCard(
                          title: settings.translate('clients'),
                          caption: settings.languageCode == 'fr' ? 'Partenariats' : 'Partnerships',
                          icon: Icons.handshake_outlined,
                          onTap: () => Navigator.pushNamed(context, '/employees'),
                        ),
                        GlassCard(
                          title: settings.translate('invoices'),
                          caption: settings.languageCode == 'fr' ? 'Règlements' : 'Settlements',
                          icon: Icons.request_quote_outlined,
                          onTap: () => Navigator.pushNamed(context, '/notifications'),
                        ),
                        GlassCard(
                          title: settings.translate('reports'),
                          caption: 'Analytics',
                          icon: Icons.analytics_outlined,
                          onTap: () => Navigator.pushNamed(context, '/notifications'),
                        ),
                        GlassCard(
                          title: settings.translate('messages'),
                          caption: 'Collaboration',
                          icon: Icons.alternate_email_outlined,
                          onTap: () => Navigator.of(context).push(ChatRouter.buildHome()),
                        ),
                        GlassCard(
                          title: settings.translate('profile'),
                          caption: settings.languageCode == 'fr' ? 'Mon Compte' : 'My Account',
                          icon: Icons.person_outlined,
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                        ),
                        GlassCard(
                          title: settings.translate('settings'),
                          caption: settings.translate('preferences'),
                          icon: Icons.tune_outlined,
                          onTap: () => Navigator.pushNamed(context, '/settings'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}