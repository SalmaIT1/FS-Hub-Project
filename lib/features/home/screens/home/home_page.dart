import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../employees/services/employee_service.dart';
import '../../../notifications/services/notification_service.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import '../../../../navigation/chat_router.dart';
import 'package:fs_hub/core/security/permission_guard.dart';

import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/core/state/location_controller.dart';

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
      duration: const Duration(milliseconds: 1000),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
    _loadUserData();
    // Temporarily force re-initialization to apply employee fallback permissions
    PermissionGuard.initialize();
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
    
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth > 1200 ? screenWidth * 0.12 : (screenWidth > 800 ? screenWidth * 0.08 : 24.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LuxuryAppBar(
        title: 'FS HUB',
        subtitle: '${_getGreeting(settings)}',
        showBackButton: false,
        isPremium: true,
      ),
      body: Stack(
        children: [
          // ── LUXURIOUS AMBIENT BACKGROUND ──────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF030303), Color(0xFF0A0A0A), Color(0xFF000000)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEDE8DF), Color(0xFFE4DDD3), Color(0xFFDBD4C8)],
                    ),
            ),
          ),
          
          // Ambient Glowing Orbs
          if (isDark) ...[
            Positioned(
              top: -150,
              right: -100,
              child: _AmbientOrb(color: Color(0xFFC9A24D).withOpacity(0.15), size: 400),
            ),
            Positioned(
              bottom: 200,
              left: -150,
              child: _AmbientOrb(color: Color(0xFFC9A24D).withOpacity(0.08), size: 500),
            ),
          ] else ...[
            Positioned(
              top: -200,
              right: -100,
              child: _AmbientOrb(color: Color(0xFFC9A24D).withOpacity(0.18), size: 450),
            ),
          ],
          
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeIn,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 30),
                      
                      // ── HERO SECTION ──────────────────────────────
                      _HeroBannerPremium(
                        isDark: isDark,
                        isFr: isFr,
                        name: _greetingName,
                        pendingCount: _pendingDemandsCount,
                        notifCount: _notificationCount,
                      ),

                      const SizedBox(height: 50),

                      // ── PRIMARY OPERATIONS ───────────────────────────
                      _LuxSectionDivider(
                        isDark: isDark,
                        label: settings.translate('ops_overview').toUpperCase(),
                      ),
                      const SizedBox(height: 24),
                      _PrimaryGrid(
                        isDark: isDark,
                        isFr: isFr,
                        pendingDemandsCount: _pendingDemandsCount,
                        settings: settings,
                      ),

                      const SizedBox(height: 50),

                      // ── SYSTEM MODULES ──────────────────────────────
                      _LuxSectionDivider(
                        isDark: isDark,
                        label: settings.translate('support_modules').toUpperCase(),
                      ),
                      const SizedBox(height: 24),
                      _SecondaryGrid(
                        isDark: isDark,
                        isFr: isFr,
                        settings: settings,
                      ),

                      const SizedBox(height: 160),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════

Widget _wrapWithGlass({required Widget child, required bool isDark}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.01) : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
          ),
        ),
        child: child,
      ),
    ),
  );
}

class _AmbientOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class _LuxSectionDivider extends StatelessWidget {
  final bool isDark;
  final String label;

  const _LuxSectionDivider({required this.isDark, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 4.0,
            color: isDark ? const Color(0xFFC9A24D) : const Color(0xFF90712B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isDark ? const Color(0xFFC9A24D).withOpacity(0.3) : const Color(0xFF90712B).withOpacity(0.2),
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
// PREMIUM HERO BANNER
// ══════════════════════════════════════════════════════════════
class _HeroBannerPremium extends StatelessWidget {
  final bool isDark;
  final bool isFr;
  final String name;
  final int pendingCount;
  final int notifCount;

  const _HeroBannerPremium({
    required this.isDark,
    required this.isFr,
    required this.name,
    required this.pendingCount,
    required this.notifCount,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF5F0E8).withOpacity(0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFC9A24D).withOpacity(0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.08),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Clock and Date Section (only on smaller screens)
              if (MediaQuery.of(context).size.width <= 600)
                _ClockSection(isDark: isDark, isFr: isFr),
              if (MediaQuery.of(context).size.width <= 600)
                const SizedBox(height: 24),
              // Main Content
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isFr ? 'ESPACE EXÉCUTIF' : 'EXECUTIVE WORKSPACE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4.0,
                            color: isDark ? const Color(0xFFC9A24D) : const Color(0xFF90712B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$name.',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w300,
                            height: 1.1,
                            letterSpacing: -1.0,
                            color: isDark ? Colors.white : const Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _LuxStatPill(
                              isDark: isDark,
                              icon: Icons.hourglass_top_rounded,
                              value: '$pendingCount',
                              label: isFr ? 'En attente' : 'Pending',
                              accent: const Color(0xFFC9A24D),
                            ),
                            _LuxStatPill(
                              isDark: isDark,
                              icon: Icons.notifications_active_outlined,
                              value: '$notifCount',
                              label: isFr ? 'Notifications' : 'Alerts',
                              accent: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Inline Clock (only on larger screens)
                  if (MediaQuery.of(context).size.width > 600)
                    _InlineClock(isDark: isDark, isFr: isFr),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LuxStatPill extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _LuxStatPill({
    required this.isDark,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CLOCK SECTION (visible on all screen sizes)
// ══════════════════════════════════════════════════════════════
class _ClockSection extends StatefulWidget {
  final bool isDark;
  final bool isFr;

  const _ClockSection({required this.isDark, required this.isFr});

  @override
  State<_ClockSection> createState() => _ClockSectionState();
}

class _ClockSectionState extends State<_ClockSection> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final months = widget.isFr
        ? ['JAN','FÉV','MAR','AVR','MAI','JUN','JUL','AOÛ','SEP','OCT','NOV','DÉC']
        : ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final days = widget.isFr
        ? ['DIM','LUN','MAR','MER','JEU','VEN','SAM']
        : ['SUN','MON','TUE','WED','THU','FRI','SAT'];
    final dateStr = '${days[_now.weekday % 7]}, ${months[_now.month - 1]} ${_now.day}, ${_now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: widget.isDark ? const Color(0xFFC9A24D) : const Color(0xFF90712B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: widget.isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 12,
                    color: widget.isDark ? const Color(0xFFC9A24D) : const Color(0xFF90712B),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.watch<LocationController>().locationLabel.isNotEmpty
                          ? context.watch<LocationController>().locationLabel
                          : (widget.isFr
                              ? 'Siège Principal'
                              : 'Main Headquarters'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: widget.isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// INLINE CLOCK (inside hero banner)
// ══════════════════════════════════════════════════════════════
class _InlineClock extends StatefulWidget {
  final bool isDark;
  final bool isFr;

  const _InlineClock({required this.isDark, required this.isFr});

  @override
  State<_InlineClock> createState() => _InlineClockState();
}

class _InlineClockState extends State<_InlineClock> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';
    final months = widget.isFr
        ? ['JAN','FÉV','MAR','AVR','MAI','JUN','JUL','AOÛ','SEP','OCT','NOV','DÉC']
        : ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final days = widget.isFr
        ? ['DIM','LUN','MAR','MER','JEU','VEN','SAM']
        : ['SUN','MON','TUE','WED','THU','FRI','SAT'];
    final dateStr = '${days[_now.weekday % 7]}, ${months[_now.month - 1]} ${_now.day}, ${_now.year}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          timeStr,
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            color: widget.isDark ? const Color(0xFFC9A24D) : const Color(0xFF90712B),
            shadows: [
              Shadow(
                color: const Color(0xFFC9A24D).withOpacity(widget.isDark ? 0.5 : 0.2),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          dateStr,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: widget.isDark ? Colors.white38 : Colors.black45,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 12,
                color: widget.isDark ? const Color(0xFFC9A24D) : const Color(0xFF90712B),
              ),
              const SizedBox(width: 6),
              Text(
                context.watch<LocationController>().locationLabel.isNotEmpty
                    ? context.watch<LocationController>().locationLabel
                    : (widget.isFr
                        ? 'Siège Principal — Opérations'
                        : 'Main Headquarters — Operations'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: widget.isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PRIMARY GRID
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
    final allItems = [
      _Module(
        title: settings.translate('employees'),
        caption: isFr ? 'Personnel & Rôles' : 'Staff Details',
        icon: Icons.group_outlined,
        route: '/employees',
      ),
      _Module(
        title: isFr ? 'Espace RH' : 'HR Portal',
        caption: isFr ? 'Pointage, Congés, Paie' : 'Attendance, Leaves, Payroll',
        icon: Icons.assignment_ind_outlined,
        route: AppRoutes.hrDashboard,
      ),
      _Module(
        title: settings.translate('projects'),
        caption: isFr ? 'Labos actifs' : 'Active Labs',
        icon: Icons.science_outlined,
        route: AppRoutes.projects,
      ),
      _Module(
        title: settings.translate('demands'),
        caption: isFr ? 'Requêtes' : 'Requests',
        icon: Icons.edit_document,
        route: '/demands',
        badge: pendingDemandsCount > 0 ? pendingDemandsCount : null,
      ),
      _Module(
        title: settings.translate('finance'),
        caption: isFr ? 'Capital & Rendement' : 'Capital Yield',
        icon: Icons.account_balance_wallet_outlined,
        route: '/finance',
      ),
      _Module(
        title: 'Credits',
        caption: isFr ? 'Gestion des Crédits' : 'Credit Management',
        icon: Icons.credit_card_outlined,
        route: AppRoutes.credits,
        isAdminOnly: true, // Mark as redundant if HR Portal is present
      ),
      _Module(
        title: 'Expenses',
        caption: isFr ? 'Dépenses & Budgets' : 'Expenses & Budgets',
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.expenses,
        isAdminOnly: true,
      ),
      _Module(
        title: 'Roles & Permissions',
        caption: isFr ? 'Gestion des Accès' : 'Access Management',
        icon: Icons.admin_panel_settings_outlined,
        route: AppRoutes.roles,
      ),
      _Module(
        title: 'Intelligence IA',
        caption: isFr ? 'Analyses Prédictives' : 'Predictive Insights',
        icon: Icons.auto_awesome,
        route: '/ai',
        isAdminOnly: false, // Keep visible for Admin/RH hubs
      ),
    ];

    // Get current user role from state if available, or fetch
    final userRole = PermissionGuard.currentRole;

    final visibleItems = allItems.where((item) {
      final route = item.route ?? '/';
      if (!PermissionGuard.canAccessRoute(route)) return false;
      
      // Declutter logic: If user is Admin/Manager, hide redundant sub-modules
      // that are already accessible via HR Portal or Finance
      if (userRole == 'Admin' || userRole == 'RH') {
        if (item.isAdminOnly == true) return false;
      }
      
      return true;
    }).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      int cols = w > 1000 ? 4 : (w > 600 ? 2 : 1);
      const gap = 20.0;
      final cardW = (w - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: visibleItems.map((item) {
          return _LuxCard(
            item: item,
            isDark: isDark,
            width: cardW,
            height: 180,
            isPrimary: true,
            onTap: () => Navigator.pushNamed(context, item.route ?? '/'),
          );
        }).toList(),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
// SECONDARY GRID
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
    final allItems = [
      _Module(title: settings.translate('tasks'), caption: 'Pipeline', icon: Icons.rule_outlined, route: AppRoutes.myTasks),
      _Module(title: settings.translate('clients'), caption: 'Partnerships', icon: Icons.handshake_outlined, route: '/clients'),
      _Module(title: settings.translate('invoices'), caption: 'Settlements', icon: Icons.receipt_long_outlined, route: '/invoices'),
      _Module(title: settings.translate('reports'), caption: 'Analytics', icon: Icons.insert_chart_outlined, route: AppRoutes.reports),
      _Module(title: settings.translate('profile'), caption: 'My Account', icon: Icons.person_outline, route: '/profile'),
      _Module(title: 'Departments', caption: 'Structure', icon: Icons.domain_outlined, route: AppRoutes.departments),
      _Module(title: settings.translate('settings'), caption: 'Preferences', icon: Icons.tune_outlined, route: AppRoutes.settings),
      _Module(
        title: isFr ? 'Historique Présence' : 'Attendance History',
        caption: isFr ? 'Consulter vos présences' : 'View your attendance',
        icon: Icons.history_rounded,
        route: AppRoutes.hrAttendanceHistory,
      ),
      _Module(
        title: isFr ? 'Demande de Congé' : 'Leave Request',
        caption: isFr ? 'Soumettre une demande' : 'Submit a request',
        icon: Icons.event_available_rounded,
        route: AppRoutes.hrLeaves,
      ),
      _Module(
        title: isFr ? 'Télétravail' : 'Remote Work',
        caption: isFr ? 'Demande de télétravail' : 'Remote work request',
        icon: Icons.home_work_rounded,
        route: AppRoutes.hrRemoteWork,
      ),
      _Module(
        title: isFr ? 'Bulletin de Paie' : 'Payslip',
        caption: isFr ? 'Consulter vos bulletins' : 'View your payslips',
        icon: Icons.payments_rounded,
        route: AppRoutes.hrSalaries,
      ),
      _Module(
        title: isFr ? 'Mes Bonus' : 'My Bonuses',
        caption: isFr ? 'Voir vos primes' : 'View your bonuses',
        icon: Icons.stars_rounded,
        route: AppRoutes.hrBonuses,
      ),
      _Module(
        title: settings.translate('messages'),
        caption: isFr ? 'Discuter avec l\'équipe' : 'Chat with team',
        icon: Icons.chat_outlined,
        route: '/chat',
      ),
    ];

    final userRole = PermissionGuard.currentRole;

    final visibleItems = allItems.where((item) {
      final route = item.isChat ? '/chat' : (item.route ?? '/');
      if (!PermissionGuard.canAccessRoute(route)) return false;

      // Declutter logic: Admins don't need "My Profile-only" modules duplicating HR modules
      // unless they want to specifically submit something for themselves.
      // But for a clean UI, we group them.
      if (userRole == 'Admin') {
        final redundantRoutes = [
          AppRoutes.hrAttendanceHistory,
          AppRoutes.hrLeaves,
          AppRoutes.hrRemoteWork,
          AppRoutes.hrSalaries,
          AppRoutes.hrBonuses
        ];
        if (redundantRoutes.contains(route)) return false;
      }

      return true;
    }).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      int cols = w > 1000 ? 4 : (w > 600 ? 3 : 2);
      const gap = 16.0;
      final cardW = (w - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: visibleItems.map((item) {
          return _LuxCard(
            item: item,
            isDark: isDark,
            width: cardW,
            height: 100,
            isPrimary: false,
            onTap: item.isChat
                ? () => Navigator.pushNamed(context, '/chat')
                : () => Navigator.pushNamed(context, item.route ?? '/'),
          );
        }).toList(),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
// UNIVERSAL LUXURY CARD
// ══════════════════════════════════════════════════════════════
class _LuxCard extends StatefulWidget {
  final _Module item;
  final bool isDark;
  final double width;
  final double height;
  final bool isPrimary;
  final VoidCallback onTap;

  const _LuxCard({
    required this.item,
    required this.isDark,
    required this.width,
    required this.height,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_LuxCard> createState() => _LuxCardState();
}

class _LuxCardState extends State<_LuxCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.95 : (_hovered ? 1.02 : 1.0);
    final borderColor = widget.isDark
        ? (_hovered ? const Color(0xFFC9A24D).withOpacity(0.5) : Colors.white.withOpacity(0.05))
        : (_hovered ? const Color(0xFFC9A24D).withOpacity(0.5) : Colors.black.withOpacity(0.10));

    final bgColor = widget.isDark
        ? (_hovered ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.02))
        : (_hovered ? const Color(0xFFF0EAE0) : const Color(0xFFEDE6DA));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTap: () {
          print('[LuxCard] Tapped on card with route: ${widget.onTap}');
          // Note: we can't print the callback itself effectively, but let's at least see the event.
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: widget.width,
                height: widget.height,
                padding: EdgeInsets.all(widget.isPrimary ? 24 : 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: _hovered && !widget.isDark ? [
                    BoxShadow(
                      color: const Color(0xFFC9A24D).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ] : [],
                ),
                child: widget.isPrimary
                    ? _buildPrimaryContent()
                    : _buildSecondaryContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFC9A24D).withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: widget.isDark ? null : Border.all(color: const Color(0xFFC9A24D).withOpacity(0.3), width: 0.8),
              ),
              child: Icon(widget.item.icon, size: 24, color: widget.isDark ? Colors.white : const Color(0xFF7A5A1E)),
            ),
            if (widget.item.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A24D),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${widget.item.badge}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            else
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.arrow_outward, color: widget.isDark ? Colors.white54 : Colors.black54, size: 18),
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              widget.item.caption.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: widget.isDark ? Colors.white38 : Colors.black45,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryContent() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFC9A24D).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: widget.isDark ? null : Border.all(color: const Color(0xFFC9A24D).withOpacity(0.25), width: 0.8),
          ),
          child: Icon(widget.item.icon, size: 20, color: widget.isDark ? Colors.white70 : const Color(0xFF7A5A1E)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.item.caption.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: widget.isDark ? Colors.white38 : Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: _hovered ? 1.0 : 0.2,
          duration: const Duration(milliseconds: 200),
          child: Icon(Icons.chevron_right, color: widget.isDark ? Colors.white54 : Colors.black54, size: 20),
        ),
      ],
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
  final String? route;
  final int? badge;
  final bool isChat;

  const _Module({
    required this.title,
    required this.caption,
    required this.icon,
    this.route,
    this.badge,
    this.isChat = false,
    this.isAdminOnly = false,
  });
  final bool isAdminOnly;
}


