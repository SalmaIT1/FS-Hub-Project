import 'package:flutter/material.dart';
import 'dart:ui';
import '../../widgets/glass_card.dart';
import '../../widgets/luxury/luxury_app_bar.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _greetingName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await AuthService.getGreetingName();
    if (mounted) {
      setState(() {
        _greetingName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: 'FS HUB',
      subtitle: 'Good evening, $_greetingName',
      actions: [
        LuxuryAppBarAction(
          icon: Icons.wb_sunny_outlined,
          onPressed: () {
            AppTheme.themeNotifier.value = ThemeMode.light;
          },
        ),
        const SizedBox(width: 8),
        LuxuryAppBarAction(
          icon: Icons.person_outline,
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        LuxuryAppBarAction(
          icon: Icons.power_settings_new_outlined,
          onPressed: () async {
            await AuthService.logout();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ],
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
        ),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
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
            padding: const EdgeInsets.only(top: 80, left: 20, right: 20, bottom: 40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth > 800) crossAxisCount = 4;
                if (constraints.maxWidth > 1200) crossAxisCount = 6;
                
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    GlassCard(
                      title: 'Employees',
                      caption: 'Staff & Roles',
                      icon: Icons.badge_outlined,
                      onTap: () => Navigator.pushNamed(context, '/employees'),
                    ),
                    GlassCard(
                      title: 'Projects',
                      caption: 'Active Labs',
                      icon: Icons.biotech_outlined,
                      onTap: () => Navigator.pushNamed(context, '/projects'),
                    ),
                    GlassCard(
                      title: 'Tasks',
                      caption: 'Pipeline',
                      icon: Icons.checklist_rtl_outlined,
                      onTap: () => Navigator.pushNamed(context, '/tasks'),
                    ),
                    GlassCard(
                      title: 'Finance',
                      caption: 'Capital & Yield',
                      icon: Icons.account_balance_outlined,
                      onTap: () => Navigator.pushNamed(context, '/finance'),
                    ),
                    GlassCard(
                      title: 'Clients',
                      caption: 'Partnerships',
                      icon: Icons.handshake_outlined,
                      onTap: () => Navigator.pushNamed(context, '/clients'),
                    ),
                    GlassCard(
                      title: 'Invoices',
                      caption: 'Settlements',
                      icon: Icons.request_quote_outlined,
                      onTap: () => Navigator.pushNamed(context, '/invoices'),
                    ),
                    GlassCard(
                      title: 'Reports',
                      caption: 'Analytics',
                      icon: Icons.analytics_outlined,
                      onTap: () => Navigator.pushNamed(context, '/reports'),
                    ),
                    GlassCard(
                      title: 'Messages',
                      caption: 'Collaboration',
                      icon: Icons.alternate_email_outlined,
                      onTap: () => Navigator.pushNamed(context, '/chat'),
                    ),
                    GlassCard(
                      title: 'Settings',
                      caption: 'Preferences',
                      icon: Icons.tune_outlined,
                      onTap: () => Navigator.pushNamed(context, '/settings'),
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