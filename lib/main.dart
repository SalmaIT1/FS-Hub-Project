import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'widgets/glass_card.dart';
import 'dart:ui';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'FS HUB',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.glassLightTheme,
          darkTheme: AppTheme.glassDarkTheme,
          themeMode: mode,
          initialRoute: AppRoutes.root,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          routes: {
            AppRoutes.root: (context) => const SplashScreen(),
            ...AppRoutes.routes,
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              toolbarHeight: 80,
              backgroundColor: isDark 
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              title: Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FS HUB',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Good evening, $_greetingName',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // Theme Toggle Button
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppTheme.themeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return IconButton(
                      onPressed: () {
                        AppTheme.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                      },
                      icon: Text(
                        isDark ? '☀️' : '🌙',
                        style: const TextStyle(fontSize: 24),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  child: Icon(
                    Icons.person_outline, 
                    size: 20, 
                    color: isDark ? Colors.white70 : Colors.black54
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.power_settings_new, 
                    color: isDark ? Colors.white24 : Colors.black26, 
                    size: 22
                  ),
                  onPressed: () async {
                    await AuthService.logout();
                    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 80, left: 20, right: 20, bottom: 40),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 6 : (MediaQuery.of(context).size.width > 800 ? 4 : 2),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              GlassCard(
                title: 'Employees',
                caption: 'Staff & Roles',
                icon: Icons.badge_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.employees),
              ),
              GlassCard(
                title: 'Projects',
                caption: 'Active Labs',
                icon: Icons.biotech_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.projects),
              ),
              GlassCard(
                title: 'Tasks',
                caption: 'Pipeline',
                icon: Icons.checklist_rtl_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.tasks),
              ),
              GlassCard(
                title: 'Finance',
                caption: 'Capital & Yield',
                icon: Icons.account_balance_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.finance),
              ),
              GlassCard(
                title: 'Clients',
                caption: 'Partnerships',
                icon: Icons.handshake_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.clients),
              ),
              GlassCard(
                title: 'Invoices',
                caption: 'Settlements',
                icon: Icons.request_quote_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.invoices),
              ),
              GlassCard(
                title: 'Reports',
                caption: 'Analytics',
                icon: Icons.analytics_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
              ),
              GlassCard(
                title: 'Messages',
                caption: 'Collaboration',
                icon: Icons.alternate_email_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.chat),
              ),
              GlassCard(
                title: 'Settings',
                caption: 'Preferences',
                icon: Icons.tune_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
