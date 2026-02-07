import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../theme/app_theme.dart';
import '../notification_badge.dart';

class LuxuryAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPress;
  final List<Widget>? actions;
  final Widget? leading;
  final double blurIntensity;
  final bool floating;
  final ScrollController? scrollController;
  final bool isPremium; // New premium flag

  const LuxuryAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBackPress,
    this.actions,
    this.leading,
    this.blurIntensity = 12.0,
    this.floating = false,
    this.scrollController,
    this.isPremium = false, // Default to enhanced premium style
  });

  @override
  Size get preferredSize => Size.fromHeight(isPremium ? 80.0 : 56.0);

  @override
  State<LuxuryAppBar> createState() => _LuxuryAppBarState();
}

class _LuxuryAppBarState extends State<LuxuryAppBar> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _blurAnimation;
  bool _isVisible = true;
  double _lastOffset = 0;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _blurAnimation = Tween<double>(
      begin: widget.blurIntensity,
      end: widget.blurIntensity * 1.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    if (widget.scrollController != null) {
      widget.scrollController!.addListener(_handleScroll);
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
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
      print('Error loading notification count: $e');
    }
  }

  void _handleScroll() {
    if (widget.scrollController == null) return;
    
    final offset = widget.scrollController!.offset;
    final delta = offset - _lastOffset;
    
    if (delta > 2 && _isVisible) {
      setState(() => _isVisible = false);
    } else if (delta < -2 && !_isVisible) {
      setState(() => _isVisible = true);
    }
    
    _lastOffset = offset;
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (widget.scrollController != null) {
      widget.scrollController!.removeListener(_handleScroll);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (widget.isPremium) {
      return _buildPremiumAppBar(context, isDark);
    }
    
    return _buildStandardAppBar(context, isDark);
  }

  Widget _buildPremiumAppBar(BuildContext context, bool isDark) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: 80.0,
        margin: widget.floating ? const EdgeInsets.fromLTRB(12, 12, 12, 0) : EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: widget.floating 
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : const BorderRadius.vertical(bottom: Radius.circular(16)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5, 1.0],
            colors: [
              isDark 
                ? const Color(0xFF1A1A1A).withValues(alpha: 0.95)
                : const Color(0xFFFFFFFF).withValues(alpha: 0.95),
              isDark 
                ? const Color(0xFF121212).withValues(alpha: 0.98)
                : const Color(0xFFF8F8F8).withValues(alpha: 0.98),
              isDark 
                ? const Color(0xFF0A0A0A).withValues(alpha: 0.99)
                : const Color(0xFFEEEEEE).withValues(alpha: 0.99),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFFC9A24D).withValues(alpha: 0.5),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                ? const Color(0xFFC9A24D).withValues(alpha: 0.15)
                : const Color(0xFF000000).withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: isDark 
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: widget.floating 
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _blurAnimation.value * 1.5,
              sigmaY: _blurAnimation.value * 1.5,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top divider line
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFC9A24D).withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Main content
                  Expanded(
                    child: Row(
                      children: [
                        // Brand block (logo and app name)
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFC9A24D).withValues(alpha: 0.15),
                                      const Color(0xFFC9A24D).withValues(alpha: 0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFC9A24D).withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: widget.leading ?? Container(
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
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.title,
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFFF4F4F4).withValues(alpha: 1.0) : const Color(0xFF0A0A0A).withValues(alpha: 1.0),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    if (widget.subtitle != null)
                                      Flexible(
                                        child: Text(
                                          widget.subtitle!,
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFFC9A24D).withValues(alpha: 0.8) : const Color(0xFF666666).withValues(alpha: 0.8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            height: 1.3,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Subtle brand underline accent
                              Container(
                                width: 2,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFFC9A24D).withValues(alpha: 0.0),
                                      const Color(0xFFC9A24D).withValues(alpha: 0.5),
                                      const Color(0xFFC9A24D).withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Right side controls - no Expanded, just right-aligned
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: _buildPremiumControls(context, isDark),
                        ),
                      ],
                    ),
                  ),
                  // Bottom divider line
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFC9A24D).withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardAppBar(BuildContext context, bool isDark) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: 56.0,
        margin: widget.floating ? const EdgeInsets.fromLTRB(8, 8, 8, 0) : EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: widget.floating 
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : const BorderRadius.vertical(bottom: Radius.circular(12)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark 
                ? const Color(0xFF121212).withValues(alpha: 0.85)
                : const Color(0xFFF4F4F4).withValues(alpha: 0.9),
              isDark 
                ? const Color(0xFF0A0A0A).withValues(alpha: 0.95)
                : const Color(0xFFE8E8E8).withValues(alpha: 0.95),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFFC9A24D).withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: widget.floating 
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _blurAnimation.value,
              sigmaY: _blurAnimation.value,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildLeading(context, isDark),
                  _buildTitleSection(isDark),
                  _buildActions(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context, bool isDark, {bool isPremium = false}) {
    if (widget.leading != null) {
      return widget.leading!;
    }
    
    if (widget.showBackButton) {
      return LuxuryAppBarAction(
        icon: CupertinoIcons.back,
        onPressed: widget.onBackPress ?? () => Navigator.maybePop(context),
        isDark: isDark,
        isPremium: isPremium,
      );
    }
    
    return const SizedBox(width: 24);
  }

  Widget _buildTitleSection(bool isDark) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: isDark ? const Color(0xFFF4F4F4).withValues(alpha: 1.0) : const Color(0xFF0A0A0A).withValues(alpha: 1.0),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: TextStyle(
                color: isDark ? const Color(0xFFC9A24D).withValues(alpha: 1.0) : const Color(0xFF888888).withValues(alpha: 1.0),
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumTitleSection(bool isDark) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: isDark ? const Color(0xFFF4F4F4).withValues(alpha: 1.0) : const Color(0xFF0A0A0A).withValues(alpha: 1.0),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: TextStyle(
                color: isDark ? const Color(0xFFC9A24D).withValues(alpha: 1.0) : const Color(0xFF666666).withValues(alpha: 1.0),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPremiumControls(BuildContext context, bool isDark) {
    // Create user menu dropdown with theme toggle, settings, logout
    final userMenu = PopupMenuButton<String>(
      icon: Icon(Icons.person_outline, color: isDark ? const Color(0xFFC9A24D) : const Color(0xFF0A0A0A)),
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'theme',
          child: ListTile(
            leading: Icon(Icons.wb_sunny_outlined),
            title: Text('Toggle Theme'),
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.power_settings_new_outlined),
            title: Text('Logout'),
          ),
        ),
      ],
      onSelected: (String value) async {
        if (value == 'theme') {
          final currentTheme = AppTheme.themeNotifier.value;
          AppTheme.themeNotifier.value = currentTheme == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
        } else if (value == 'settings') {
          Navigator.pushNamed(context, '/settings');
        } else if (value == 'logout') {
          await AuthService.logout();
          if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
        }
      },
    );

    List<Widget> controls = [];
    
    // Always add notification badge
    controls.add(NotificationBadge(
      notificationCount: _notificationCount,
      onTap: () => Navigator.pushNamed(context, '/notifications'),
    ));
    controls.add(const SizedBox(width: 4)); // Reduced spacing
    
    // Add notification badge if present in actions
    if (widget.actions != null) {
      for (var action in widget.actions!) {
        // Look for notification badge based on type
        if (action.runtimeType.toString().contains('NotificationBadge')) {
          controls.add(Container(
            width: 48,
            height: 48,
            child: action,
          ));
          controls.add(const SizedBox(width: 4)); // Reduced spacing
          break; // Add only the first notification badge
        }
      }
    }

    controls.add(Container(
      width: 48,
      height: 48,
      child: userMenu,
    ));

    return controls;
  }

  Widget _buildActions(bool isDark) {
    if (widget.actions == null || widget.actions!.isEmpty) {
      return const SizedBox(width: 24);
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.actions!.map((action) {
        if (action is LuxuryAppBarAction) {
          return LuxuryAppBarAction(
            icon: action.icon,
            onPressed: action.onPressed,
            isDark: isDark,
          );
        }
        return action;
      }).toList(),
    );
  }

  Widget _buildPremiumActions(bool isDark) {
    if (widget.actions == null || widget.actions!.isEmpty) {
      return const SizedBox(width: 24);
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.actions!.map((action) {
        if (action is LuxuryAppBarAction) {
          return LuxuryAppBarAction(
            icon: action.icon,
            onPressed: action.onPressed,
            isDark: isDark,
            isPremium: true,
          );
        }
        return action;
      }).toList(),
    );
  }
}

class LuxuryAppBarAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDark;
  final bool isPremium;

  const LuxuryAppBarAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.isDark = true,
    this.isPremium = false,
  });

  @override
  State<LuxuryAppBarAction> createState() => _LuxuryAppBarActionState();
}

class _LuxuryAppBarActionState extends State<LuxuryAppBarAction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: widget.isPremium
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.isDark 
                      ? const Color(0xFFC9A24D).withValues(alpha: 0.2)
                      : const Color(0xFF0A0A0A).withValues(alpha: 0.1),
                    widget.isDark 
                      ? const Color(0xFFC9A24D).withValues(alpha: 0.1)
                      : const Color(0xFF0A0A0A).withValues(alpha: 0.05),
                  ],
                )
              : null,
            color: !widget.isPremium
              ? (widget.isDark 
                  ? const Color(0xFFC9A24D).withValues(alpha: 0.1)
                  : const Color(0xFF0A0A0A).withValues(alpha: 0.05))
              : null,
            borderRadius: BorderRadius.circular(widget.isPremium ? 12 : 8),
            border: widget.isPremium
              ? Border.all(
                  color: const Color(0xFFC9A24D).withValues(alpha: 0.3),
                  width: 1.0,
                )
              : null,
            boxShadow: widget.isPremium
              ? [
                  BoxShadow(
                    color: const Color(0xFFC9A24D).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          ),
          child: Icon(
            widget.icon,
            size: widget.isPremium ? 20 : 16,
            color: widget.isDark ? const Color(0xFFC9A24D).withValues(alpha: 1.0) : const Color(0xFF0A0A0A).withValues(alpha: 1.0),
          ),
        ),
      ),
    );
  }
}

class LuxurySearchInline extends StatefulWidget {
  final ValueChanged<String>? onQueryChanged;
  final VoidCallback? onClear;
  final String? hintText;
  final bool autoFocus;

  const LuxurySearchInline({
    super.key,
    this.onQueryChanged,
    this.onClear,
    this.hintText,
    this.autoFocus = false,
  });

  @override
  State<LuxurySearchInline> createState() => _LuxurySearchInlineState();
}

class _LuxurySearchInlineState extends State<LuxurySearchInline> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    widget.onQueryChanged?.call(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark 
          ? const Color(0xFF121212).withValues(alpha: 0.7)
          : const Color(0xFFF4F4F4).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark 
            ? const Color(0xFFC9A24D).withValues(alpha: 0.2)
            : const Color(0xFF0A0A0A).withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autoFocus,
        style: TextStyle(
          color: isDark ? const Color(0xFFF4F4F4) : const Color(0xFF0A0A0A),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search...',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF888888).withValues(alpha: 1.0) : const Color(0xFF666666).withValues(alpha: 1.0),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 16,
            color: isDark ? const Color(0xFFC9A24D) : const Color(0xFF888888),
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _controller.clear();
                    widget.onClear?.call();
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: isDark ? const Color(0xFF888888).withValues(alpha: 1.0) : const Color(0xFF666666).withValues(alpha: 1.0),
                  ),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class LuxuryScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPress;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget body;
  final bool floatingAppBar;
  final ScrollController? scrollController;
  final Widget? bottomNavigationBar;
  final bool isPremium; // New premium flag

  const LuxuryScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBackPress,
    this.actions,
    this.leading,
    required this.body,
    this.floatingAppBar = false,
    this.scrollController,
    this.bottomNavigationBar,
    this.isPremium = true, // Default to premium for enhanced pages
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF4F4F4),
      appBar: LuxuryAppBar(
        title: title,
        subtitle: subtitle,
        showBackButton: showBackButton,
        onBackPress: onBackPress,
        actions: actions,
        leading: leading,
        floating: floatingAppBar,
        scrollController: scrollController,
        isPremium: isPremium,
      ),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}