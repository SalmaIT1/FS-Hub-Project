import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../employees/services/employee_service.dart';
import '../../../notifications/services/notification_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../navigation/chat_router.dart';

import 'package:provider/provider.dart';
import '../../../../core/state/settings_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  String _greetingName = 'User';
  int _pendingDemandsCount = 0;
  int _notificationCount = 0;
  String? _userRole;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final name = await AuthService.getGreetingName();
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _greetingName = name;
        _userRole = user?['role'];
      });
    }
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final demandsResult = await EmployeeService.getAllDemands(status: 'pending');
      if (demandsResult['success']) {
        final List<dynamic> demands = demandsResult['data'];
        if (_userRole != 'Admin') {
          final user = await AuthService.getCurrentUser();
          if (user != null) {
            demands.removeWhere((d) => d['requesterId'] != user['id']);
          }
        }
        if (mounted) setState(() => _pendingDemandsCount = demands.length);
      }

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser != null) {
        final result = await NotificationService.getUserNotifications(currentUser['id']);
        if (result['success']) {
          final List<dynamic> notifs = result['data'];
          if (mounted) {
            setState(() => _notificationCount = notifs.where((n) => (n is Map && n['isRead'] == false) || (n.isRead == false)).length);
          }
        }
      }
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }
  }

  String _getGreeting(SettingsController s) {
    final h = DateTime.now().hour;
    if (h < 12) return s.translate('good_morning');
    if (h < 17) return s.translate('good_afternoon');
    return s.translate('good_evening');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();
    final isFr = settings.languageCode == 'fr';

    // Responsive horizontal padding based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth > 1200
        ? screenWidth * 0.10   // wide desktop: 10% side margins
        : screenWidth > 700
            ? screenWidth * 0.05  // tablet/small desktop: 5%
            : 20.0;               // mobile: fixed 20px

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'FS Hub',
        subtitle: '${_getGreeting(settings)}, ${_greetingName.isNotEmpty ? _greetingName : 'User'}',
        showBackButton: false,
        isPremium: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D0D0D), Color(0xFF141414), Color(0xFF0A0A0A)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF4F6FA), Color(0xFFEBEEF5), Color(0xFFF0F3F9)],
                ),
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),

                    // ── HERO BANNER ──────────────────────────────
                    _HeroBanner(
                      isDark: isDark,
                      isFr: isFr,
                      name: _greetingName,
                      pendingCount: _pendingDemandsCount,
                      notifCount: _notificationCount,
                    ),

                    const SizedBox(height: 40),

                    // ── PRIMARY MODULES ───────────────────────────
                    _SectionHeader(
                      isDark: isDark,
                      label: settings.translate('ops_overview').toUpperCase(),
                      icon: Icons.hub_outlined,
                    ),
                    const SizedBox(height: 18),
                    _PrimaryGrid(
                      isDark: isDark,
                      isFr: isFr,
                      pendingDemandsCount: _pendingDemandsCount,
                      settings: settings,
                    ),

                    const SizedBox(height: 44),

                    // ── SECONDARY MODULES ─────────────────────────
                    _SectionHeader(
                      isDark: isDark,
                      label: settings.translate('support_modules').toUpperCase(),
                      icon: Icons.apps_outlined,
                    ),
                    const SizedBox(height: 18),
                    _SecondaryGrid(
                      isDark: isDark,
                      isFr: isFr,
                      settings: settings,
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HERO BANNER
// ══════════════════════════════════════════════════════════════
class _HeroBanner extends StatelessWidget {
  final bool isDark;
  final bool isFr;
  final String name;
  final int pendingCount;
  final int notifCount;

  const _HeroBanner({
    required this.isDark,
    required this.isFr,
    required this.name,
    required this.pendingCount,
    required this.notifCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFC9A24D).withOpacity(0.16),
                  const Color(0xFF1C1C1C).withOpacity(0.92),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFC9A24D).withOpacity(0.10),
                  Colors.white.withOpacity(0.95),
                ],
              ),
        border: Border.all(
          color: const Color(0xFFC9A24D).withOpacity(isDark ? 0.22 : 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC9A24D).withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: text + stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFr ? 'TABLEAU DE BORD' : 'OPERATIONS HUB',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: const Color(0xFFC9A24D).withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isFr ? 'Bonjour,\n$name' : 'Welcome back,\n$name',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: 0.1,
                    color: isDark ? Colors.white : const Color(0xFF0D1117),
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _StatPill(
                      isDark: isDark,
                      icon: Icons.pending_actions_outlined,
                      value: '$pendingCount',
                      label: isFr ? 'En attente' : 'Pending',
                      accent: const Color(0xFFF07E4A),
                    ),
                    _StatPill(
                      isDark: isDark,
                      icon: Icons.notifications_none_outlined,
                      value: '$notifCount',
                      label: isFr ? 'Alertes' : 'Alerts',
                      accent: const Color(0xFF5E9BF0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right: decorative orb
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFC9A24D).withOpacity(0.30),
                  const Color(0xFFC9A24D).withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFC9A24D).withOpacity(0.30),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.hub_outlined,
              color: Color(0xFFC9A24D),
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _StatPill({
    required this.isDark,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withOpacity(0.22),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0D1117),
                  height: 1.0,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECTION HEADER
// ══════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final bool isDark;
  final String label;
  final IconData icon;

  const _SectionHeader({
    required this.isDark,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFFC9A24D).withOpacity(0.80)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: isDark
                ? Colors.white.withOpacity(0.45)
                : Colors.black.withOpacity(0.38),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isDark ? Colors.white : Colors.black).withOpacity(0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PRIMARY GRID  — responsive, large cards
// ══════════════════════════════════════════════════════════════
class _PrimaryGrid extends StatelessWidget {
  final bool isDark;
  final bool isFr;
  final int pendingDemandsCount;
  final SettingsController settings;

  const _PrimaryGrid({
    required this.isDark,
    required this.isFr,
    required this.pendingDemandsCount,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _Module(
        title: settings.translate('employees'),
        caption: isFr ? 'Personnel & Rôles' : 'Staff & Roles',
        icon: Icons.badge_outlined,
        accent: const Color(0xFF5E9BF0),
        route: '/employees',
      ),
      _Module(
        title: settings.translate('projects'),
        caption: isFr ? 'Labos actifs' : 'Active Labs',
        icon: Icons.rocket_launch_outlined,
        accent: const Color(0xFF8B7CF5),
        route: AppRoutes.projects,
      ),
      _Module(
        title: settings.translate('demands'),
        caption: isFr ? 'Requêtes' : 'Requests',
        icon: Icons.assignment_outlined,
        accent: const Color(0xFFF07E4A),
        route: '/demands',
        badge: pendingDemandsCount > 0 ? pendingDemandsCount : null,
      ),
      _Module(
        title: settings.translate('finance'),
        caption: isFr ? 'Capital & Rendement' : 'Capital & Yield',
        icon: Icons.account_balance_outlined,
        accent: const Color(0xFF4ABF8A),
        route: '/finance',
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      // On wide screens show 4 in a row, on medium 2, on narrow 2
      int cols = w > 900 ? 4 : 2;
      const gap = 16.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      // Card height scales with width for portrait feel on mobile,
      // stays fixed and comfortable on wide screens
      final cardH = w > 900 ? 180.0 : 170.0;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: items.map((item) {
          return _PrimaryCard(
            item: item,
            isDark: isDark,
            width: cardW,
            height: cardH,
          );
        }).toList(),
      );
    });
  }
}

class _PrimaryCard extends StatefulWidget {
  final _Module item;
  final bool isDark;
  final double width;
  final double height;

  const _PrimaryCard({
    required this.item,
    required this.isDark,
    required this.width,
    required this.height,
  });

  @override
  State<_PrimaryCard> createState() => _PrimaryCardState();
}

class _PrimaryCardState extends State<_PrimaryCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final elevated = _hovered || _pressed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          Navigator.pushNamed(context, item.route ?? '/');
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 130),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        item.accent.withOpacity(elevated ? 0.22 : 0.14),
                        item.accent.withOpacity(elevated ? 0.10 : 0.04),
                      ]
                    : [
                        item.accent.withOpacity(elevated ? 0.16 : 0.09),
                        item.accent.withOpacity(elevated ? 0.06 : 0.02),
                      ],
              ),
              border: Border.all(
                color: item.accent.withOpacity(elevated ? 0.38 : 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.accent.withOpacity(elevated ? 0.22 : 0.08),
                  blurRadius: elevated ? 24 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: icon + badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, size: 24, color: item.accent),
                    ),
                    if (item.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF07E4A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${item.badge}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      AnimatedOpacity(
                        opacity: _hovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.north_east_rounded,
                          size: 16,
                          color: item.accent.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),

                // Bottom: title + caption
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: isDark ? Colors.white : const Color(0xFF0D1117),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.caption,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? Colors.white.withOpacity(0.42)
                            : Colors.black.withOpacity(0.40),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECONDARY GRID  — responsive, airy cards
// ══════════════════════════════════════════════════════════════
class _SecondaryGrid extends StatelessWidget {
  final bool isDark;
  final bool isFr;
  final SettingsController settings;

  const _SecondaryGrid({
    required this.isDark,
    required this.isFr,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _Module(
        title: settings.translate('tasks'),
        caption: 'Pipeline',
        icon: Icons.checklist_rtl_outlined,
        accent: const Color(0xFFF0B44A),
        route: AppRoutes.myTasks,
      ),
      _Module(
        title: settings.translate('clients'),
        caption: isFr ? 'Partenariats' : 'Partnerships',
        icon: Icons.handshake_outlined,
        accent: const Color(0xFF4ABFF0),
        route: '/clients',
      ),
      _Module(
        title: settings.translate('invoices'),
        caption: isFr ? 'Règlements' : 'Settlements',
        icon: Icons.request_quote_outlined,
        accent: const Color(0xFF9BCE67),
        route: '/invoices',
      ),
      _Module(
        title: settings.translate('reports'),
        caption: 'Analytics',
        icon: Icons.analytics_outlined,
        accent: const Color(0xFFF06A9B),
        route: '/notifications',
      ),
      _Module(
        title: settings.translate('messages'),
        caption: 'Collaboration',
        icon: Icons.alternate_email_outlined,
        accent: const Color(0xFF6AB0F5),
        isChat: true,
      ),
      _Module(
        title: settings.translate('profile'),
        caption: isFr ? 'Mon Compte' : 'My Account',
        icon: Icons.person_outline,
        accent: const Color(0xFFC9A24D),
        route: '/profile',
      ),
      _Module(
        title: 'Departments',
        caption: isFr ? 'Org. Structure' : 'Org Structure',
        icon: Icons.account_tree_outlined,
        accent: const Color(0xFF9B87F5),
        route: AppRoutes.departments,
      ),
      _Module(
        title: settings.translate('settings'),
        caption: settings.translate('preferences'),
        icon: Icons.tune_outlined,
        accent: const Color(0xFF7A8BA0),
        route: '/settings',
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      int cols = w > 900 ? 4 : w > 580 ? 3 : 2;
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      const cardH = 90.0;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: items.map((item) {
          return _SecondaryCard(
            item: item,
            isDark: isDark,
            width: cardW,
            height: cardH,
            onTap: item.isChat
                ? () => Navigator.of(context).push(ChatRouter.buildHome())
                : () => Navigator.pushNamed(context, item.route ?? '/'),
          );
        }).toList(),
      );
    });
  }
}

class _SecondaryCard extends StatefulWidget {
  final _Module item;
  final bool isDark;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _SecondaryCard({
    required this.item,
    required this.isDark,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<_SecondaryCard> createState() => _SecondaryCardState();
}

class _SecondaryCardState extends State<_SecondaryCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final elevated = _hovered || _pressed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: isDark
                  ? Colors.white.withOpacity(elevated ? 0.09 : 0.05)
                  : Colors.white.withOpacity(elevated ? 0.95 : 0.80),
              border: Border.all(
                color: elevated
                    ? item.accent.withOpacity(0.30)
                    : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.07)),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: elevated
                      ? item.accent.withOpacity(0.14)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: elevated ? 18 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.accent.withOpacity(elevated ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 20, color: item.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: isDark ? Colors.white : const Color(0xFF0D1117),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.caption,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withOpacity(0.38)
                              : Colors.black.withOpacity(0.38),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: item.accent.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DATA MODEL
// ══════════════════════════════════════════════════════════════
class _Module {
  final String title;
  final String caption;
  final IconData icon;
  final Color accent;
  final String? route;
  final int? badge;
  final bool isChat;

  const _Module({
    required this.title,
    required this.caption,
    required this.icon,
    required this.accent,
    this.route,
    this.badge,
    this.isChat = false,
  });
}