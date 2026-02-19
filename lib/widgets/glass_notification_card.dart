import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';

class GlassNotificationCard extends StatefulWidget {
  final String title;
  final String message;
  final String timestamp;
  final bool isRead;
  final String type;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;

  const GlassNotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.type,
    this.onTap,
    this.onMarkAsRead,
  });

  @override
  State<GlassNotificationCard> createState() => _GlassNotificationCardState();
}

class _GlassNotificationCardState extends State<GlassNotificationCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime parsedTime = DateTime.tryParse(widget.timestamp) ?? DateTime.now();
    final String formattedTime = DateFormat('HH:mm').format(parsedTime);
    final String formattedDate = DateFormat('MMM dd').format(parsedTime);

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(widget.isRead ? 0.03 : 0.08),
                      Colors.white.withOpacity(widget.isRead ? 0.01 : 0.03),
                    ]
                  : [
                      Colors.black.withOpacity(widget.isRead ? 0.02 : 0.05),
                      Colors.black.withOpacity(widget.isRead ? 0.01 : 0.02),
                    ],
            ),
            border: Border.all(
              color: widget.isRead
                  ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))
                  : AppTheme.accentGold.withOpacity(0.4),
              width: widget.isRead ? 0.5 : 1.2,
            ),
            boxShadow: [
              if (!widget.isRead)
                BoxShadow(
                  color: AppTheme.accentGold.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Status indicator & Icon
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getIconBackgroundColor(widget.type, isDark, widget.isRead),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: widget.isRead 
                                  ? Colors.transparent 
                                  : AppTheme.accentGold.withOpacity(0.2),
                            ),
                          ),
                          child: Icon(
                            _getIconForType(widget.type),
                            size: 20,
                            color: _getIconColor(widget.type, isDark, widget.isRead),
                          ),
                        ),
                        if (!widget.isRead)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getTypeLabel(widget.type),
                                style: TextStyle(
                                  color: AppTheme.accentGold.withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                '$formattedTime • $formattedDate',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 15,
                              fontWeight: widget.isRead ? FontWeight.w500 : FontWeight.w700,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'demand': return 'SYSTEM DEMAND';
      case 'system': return 'SECURITY ALERT';
      case 'message': return 'DIRECT MESSAGE';
      default: return 'NOTIFICATION';
    }
  }

  Color _getIconBackgroundColor(String type, bool isDark, bool isRead) {
    if (isRead) return isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    
    switch (type) {
      case 'demand':
        return AppTheme.accentGold.withOpacity(0.15);
      case 'system':
        return Colors.blue.withOpacity(0.15);
      default:
        return AppTheme.accentGold.withOpacity(0.1);
    }
  }

  Color _getIconColor(String type, bool isDark, bool isRead) {
    if (isRead) return isDark ? Colors.white38 : Colors.black38;

    switch (type) {
      case 'demand':
        return AppTheme.accentGold;
      case 'system':
        return Colors.blueAccent;
      default:
        return AppTheme.accentGold;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'demand':
        return Icons.assignment_rounded;
      case 'system':
        return Icons.gpp_maybe_rounded;
      case 'message':
        return Icons.forum_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }
}
