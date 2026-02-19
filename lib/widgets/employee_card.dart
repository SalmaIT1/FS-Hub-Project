import 'dart:ui';
import 'package:flutter/material.dart';
import '../shared/models/employee_model.dart';
import '../core/theme/app_theme.dart';
import '../core/localization/translations.dart';
import '../core/state/settings_controller.dart';

class EmployeeCard extends StatefulWidget {
  final Employee employee;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EmployeeCard({
    super.key,
    required this.employee,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<EmployeeCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.employee.statut.toLowerCase()) {
      case 'actif':
        return const Color(0xFF4CAF50);
      case 'suspendu':
        return const Color(0xFFFFA726);
      case 'démission':
        return const Color(0xFFEF5350);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();
    final languageCode = settings.languageCode;
    
    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _hoverController.reverse();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _hoverController.forward();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                if (_isPressed || _hoverController.isAnimating || _hoverController.value > 0)
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.15 * _hoverController.value),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative background accent
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.accentGold.withOpacity(0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _buildAvatar(isDark),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.employee.fullName,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : Colors.black,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _buildStatusBadge(),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.employee.poste,
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.corporate_fare_rounded,
                                        size: 14,
                                        color: AppTheme.accentGold.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          widget.employee.departement,
                                          style: TextStyle(
                                            color: isDark ? Colors.white38 : Colors.black45,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (widget.onEdit != null || widget.onDelete != null)
                              _buildActionMenu(isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildAvatar(bool isDark) {
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentGold.withOpacity(0.2),
                AppTheme.accentGold.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: widget.employee.isOnline 
                  ? const Color(0xFF4CAF50).withOpacity(0.5) 
                  : AppTheme.accentGold.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.employee.isOnline 
                    ? const Color(0xFF4CAF50).withOpacity(0.2) 
                    : Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: widget.employee.avatarUrl != null
                ? _buildImageWidget(widget.employee.avatarUrl!, isDark)
                : _buildAvatarPlaceholder(isDark),
          ),
        ),
        if (widget.employee.isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

Widget _buildImageWidget(String avatarUrl, bool isDark) {
  if (avatarUrl.startsWith('data:')) {
    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(isDark),
    );
  } else if (avatarUrl.length > 100) {
    return Image.network(
      'data:image/jpeg;base64,$avatarUrl',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(isDark),
    );
  } else {
    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(isDark),
    );
  }
}

  Widget _buildAvatarPlaceholder(bool isDark) {
    String initials = '';
    if (widget.employee.prenom.isNotEmpty) initials += widget.employee.prenom[0];
    if (widget.employee.nom.isNotEmpty) initials += widget.employee.nom[0];
    if (initials.isEmpty) initials = '?';
    
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.accentGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusColor = _getStatusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.employee.statut,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(bool isDark) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        color: isDark ? Colors.white38 : Colors.black26,
      ),
      offset: const Offset(0, 40),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      onSelected: (value) {
        if (value == 'edit' && widget.onEdit != null) widget.onEdit!();
        if (value == 'delete' && widget.onDelete != null) widget.onDelete!();
      },
      itemBuilder: (context) => [
        if (widget.onEdit != null)
          _buildMenuItem(
            'edit',
            Translations.getText('edit_profile', languageCode),
            Icons.edit_rounded,
            isDark ? Colors.white : Colors.black,
          ),
        if (widget.onDelete != null)
          _buildMenuItem(
            'delete',
            Translations.getText('remove', languageCode),
            Icons.delete_outline_rounded,
            Colors.redAccent,
          ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color.withOpacity(0.7)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
