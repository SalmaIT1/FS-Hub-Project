import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/data/services/auth_service.dart';
import '../../../features/notifications/services/notification_service.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import '../../../features/chat/presentation/widgets/avatar_helper.dart';

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
  final String? avatarUrl;
  final String? initials;
  final bool isGroup;
  final PreferredSizeWidget? bottom;
  final bool showDefaultActions; // New flag to toggle default premium actions

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
    this.avatarUrl,
    this.initials,
    this.isGroup = false,
    this.bottom,
    this.showDefaultActions = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      (isPremium ? 90.0 : 56.0) + (bottom?.preferredSize.height ?? 0.0));

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
        final notificationsResult = await NotificationService.getUserNotifications(userId);
        if (notificationsResult['success']) {
          final List<dynamic> notifications = notificationsResult['data'];
          final unreadCount = notifications.where((n) => n.isRead == false).length;
          
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
        height: widget.preferredSize.height,
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
            child: SafeArea(
              bottom: false,
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
                        if (widget.showBackButton) ...[
                          _buildLeading(context, isDark, isPremium: true),
                          const SizedBox(width: 8),
                        ],
                        // Brand block (logo and app name)
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => route.isFirst),
                            behavior: HitTestBehavior.opaque,
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
                                  child: (widget.avatarUrl != null || widget.initials != null)
                                      ? AvatarHelper.buildAvatar(
                                          widget.avatarUrl,
                                          size: 40,
                                          isGroup: widget.isGroup,
                                          initials: widget.initials,
                                        )
                                      : (widget.leading ?? Container(
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
                                        )),
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                  if (widget.bottom != null) widget.bottom!,
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
    ),
  );
}

  Widget _buildStandardAppBar(BuildContext context, bool isDark) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: widget.preferredSize.height,
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
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
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
            if (widget.bottom != null) widget.bottom!,
          ],
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
        onPressed: widget.onBackPress ?? () async {
          bool canPop = await Navigator.maybePop(context);
          if (!canPop && context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => route.isFirst);
          }
        },
        isDark: isDark,
        isPremium: isPremium,
      );
    }
    
    return const SizedBox(width: 24);
  }

  Widget _buildTitleSection(bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => route.isFirst),
        behavior: HitTestBehavior.opaque,
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
    List<Widget> controls = [];
    
    // 1. Add custom actions if provided
    if (widget.actions != null) {
      for (var action in widget.actions!) {
        // Skip notification badge if we're adding it manually below
        if (!action.runtimeType.toString().contains('NotificationBadge')) {
          controls.add(action);
          controls.add(const SizedBox(width: 8));
        }
      }
    }

     // 2. Add default actions only if showDefaultActions is true
    if (widget.showDefaultActions) {
      // Notification badge dropdown
      controls.add(_NotificationDropdownButton(
        notificationCount: _notificationCount,
        isDark: isDark,
        onCountChanged: (count) {
          if (mounted) setState(() => _notificationCount = count);
        },
      ));
      controls.add(const SizedBox(width: 8));
      
      // User menu dropdown
      controls.add(_UserMenuDropdownButton(isDark: isDark, appBarContext: context));
    }

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

// ══════════════════════════════════════════════════════════════
// NOTIFICATION DROPDOWN BUTTON
// ══════════════════════════════════════════════════════════════
class _NotificationDropdownButton extends StatefulWidget {
  final int notificationCount;
  final bool isDark;
  final ValueChanged<int> onCountChanged;

  const _NotificationDropdownButton({
    required this.notificationCount,
    required this.isDark,
    required this.onCountChanged,
  });

  @override
  State<_NotificationDropdownButton> createState() => _NotificationDropdownButtonState();
}

class _NotificationDropdownButtonState extends State<_NotificationDropdownButton> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();
  List<dynamic> _notifications = [];
  bool _loading = false;
  String? _currentUserId;

  Future<void> _loadNotifications() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        _currentUserId = user['id'].toString();
        final result = await NotificationService.getUserNotifications(_currentUserId!);
        if (result['success']) {
          _notifications = (result['data'] as List).take(5).toList();
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showDropdown() async {
    await _loadNotifications();
    if (!mounted) return;

    final renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _NotificationDropdownOverlay(
        position: Offset(offset.dx, offset.dy + size.height + 8),
        notifications: _notifications,
        isDark: widget.isDark,
        currentUserId: _currentUserId,
        onDismiss: _removeDropdown,
        onMarkRead: (notif) async {
          if (_currentUserId != null) {
            await NotificationService.markAsRead(notif.id, _currentUserId!);
            await _loadNotifications();
            final unread = _notifications.where((n) => n.isRead == false).length;
            widget.onCountChanged(unread);
            _removeDropdown();
            _showDropdown();
          }
        },
        onShowAll: () {
          _removeDropdown();
          Navigator.pushNamed(ctx, '/notifications');
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: _toggleDropdown,
      child: Container(
        width: 48,
        height: 48,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 20,
              color: widget.isDark
                  ? const Color(0xFFC9A24D)
                  : const Color(0xFF0A0A0A),
            ),
            if (widget.notificationCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC9A24D),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDropdownOverlay extends StatelessWidget {
  final Offset position;
  final List<dynamic> notifications;
  final bool isDark;
  final String? currentUserId;
  final VoidCallback onDismiss;
  final Function(dynamic) onMarkRead;
  final VoidCallback onShowAll;

  const _NotificationDropdownOverlay({
    required this.position,
    required this.notifications,
    required this.isDark,
    required this.currentUserId,
    required this.onDismiss,
    required this.onMarkRead,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const dropWidth = 340.0;
    final left = (position.dx + dropWidth > screenWidth - 12)
        ? screenWidth - dropWidth - 12
        : position.dx;

    return Stack(
      children: [
        // Dismiss tap area
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Dropdown panel
        Positioned(
          top: position.dy,
          left: left,
          width: dropWidth,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111111).withOpacity(0.97) : const Color(0xFFF5F0E8).withOpacity(0.98),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFC9A24D).withOpacity(isDark ? 0.25 : 0.30),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              size: 16,
                              color: const Color(0xFFC9A24D),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'NOTIFICATIONS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const Spacer(),
                            if (notifications.any((n) => n.isRead == false))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC9A24D).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: const Color(0xFFC9A24D).withOpacity(0.4)),
                                ),
                                child: Text(
                                  '${notifications.where((n) => n.isRead == false).length} new',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC9A24D),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Gold divider
                      Container(
                        height: 0.5,
                        color: const Color(0xFFC9A24D).withOpacity(0.2),
                      ),
                      // Notification list
                      if (notifications.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                          child: Center(
                            child: Text(
                              'No notifications',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        )
                      else
                        ...notifications.map((notif) {
                          final unread = notif.isRead == false;
                          return GestureDetector(
                            onTap: unread ? () => onMarkRead(notif) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: unread
                                    ? const Color(0xFFC9A24D).withOpacity(isDark ? 0.06 : 0.08)
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Unread dot
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, right: 12),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: unread
                                            ? const Color(0xFFC9A24D)
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          notif.message,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : Colors.black54,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (notif.timestamp.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            notif.timestamp,
                                            style: TextStyle(
                                              fontSize: 9,
                                              letterSpacing: 0.5,
                                              color: isDark ? Colors.white30 : Colors.black38,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (unread)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 2),
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        size: 14,
                                        color: const Color(0xFFC9A24D).withOpacity(0.6),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      // Footer: Show all
                      GestureDetector(
                        onTap: onShowAll,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC9A24D).withOpacity(isDark ? 0.08 : 0.06),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'SHOW ALL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.0,
                                    color: const Color(0xFFC9A24D),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward, size: 12, color: Color(0xFFC9A24D)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
    final settings = context.watch<SettingsController>();
    
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
          hintText: widget.hintText ?? settings.translate('search'),
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
  final bool isPremium;
  final bool extendBody;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;

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
    this.isPremium = true,
    this.extendBody = false,
    this.bottom,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF121212)
        : const Color(0xFFF8F8F8),
      extendBody: extendBody,
      extendBodyBehindAppBar: true,
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
        bottom: bottom,
      ),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// USER MENU DROPDOWN BUTTON
// ══════════════════════════════════════════════════════════════
class _UserMenuDropdownButton extends StatefulWidget {
  final bool isDark;
  final BuildContext appBarContext;

  const _UserMenuDropdownButton({required this.isDark, required this.appBarContext});

  @override
  State<_UserMenuDropdownButton> createState() => _UserMenuDropdownButtonState();
}

class _UserMenuDropdownButtonState extends State<_UserMenuDropdownButton> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();

  void _showDropdown() {
    if (!mounted) return;

    final renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _UserMenuDropdownOverlay(
        position: Offset(offset.dx, offset.dy + size.height + 8),
        isDark: widget.isDark,
        onDismiss: _removeDropdown,
        appBarContext: widget.appBarContext,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: _toggleDropdown,
      child: Container(
        width: 48,
        height: 48,
        color: Colors.transparent,
        child: Icon(
          Icons.menu_rounded,
          size: 20,
          color: widget.isDark
              ? const Color(0xFFC9A24D)
              : const Color(0xFF0A0A0A),
        ),
      ),
    );
  }
}

class _UserMenuDropdownOverlay extends StatelessWidget {
  final Offset position;
  final bool isDark;
  final VoidCallback onDismiss;
  final BuildContext appBarContext;

  const _UserMenuDropdownOverlay({
    required this.position,
    required this.isDark,
    required this.onDismiss,
    required this.appBarContext,
  });

  @override
  Widget build(BuildContext context) {
    final settings = appBarContext.read<SettingsController>();

    final screenWidth = MediaQuery.of(context).size.width;
    const dropWidth = 240.0;
    final left = (position.dx + dropWidth > screenWidth - 12)
        ? screenWidth - dropWidth - 12
        : position.dx;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: position.dy,
          left: left,
          width: dropWidth,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111111).withOpacity(0.97) : const Color(0xFFF5F0E8).withOpacity(0.98),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFC9A24D).withOpacity(isDark ? 0.25 : 0.30),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.menu_rounded,
                              size: 16,
                              color: const Color(0xFFC9A24D),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              settings.languageCode == 'fr' ? 'PRÉFÉRENCES' : 'PREFERENCES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 0.5,
                        color: const Color(0xFFC9A24D).withOpacity(0.2),
                      ),
                      const SizedBox(height: 8),
                      // Theme Toggle
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.wb_sunny_outlined,
                        label: settings.languageCode == 'fr' ? 'Changer de thème' : 'Toggle Theme',
                        onTap: () async {
                          onDismiss();
                          await AppTheme.toggleTheme();
                        },
                      ),
                      // Settings
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.settings_outlined,
                        label: settings.translate('settings'),
                        onTap: () {
                          onDismiss();
                          Navigator.pushNamed(appBarContext, '/settings');
                        },
                      ),
                      // Logout
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.power_settings_new_outlined,
                        label: settings.translate('logout'),
                        isDestructive: true,
                        onTap: () async {
                          onDismiss();
                          try {
                            await appBarContext.read<ChatController>().logout();
                          } catch (e) {
                            print('Error during chat logout: $e');
                          }
                          await AuthService.logout();
                          if (appBarContext.mounted) {
                            Navigator.pushReplacementNamed(appBarContext, '/login');
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDestructive 
                  ? Colors.red[400] 
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDestructive
                    ? Colors.red[400]
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

