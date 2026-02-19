import 'dart:ui';
import 'package:flutter/material.dart';
import '../../shared/models/demand_model.dart';
import 'package:fs_hub/core/localization/translations.dart';
import '../../core/state/settings_controller.dart';

class DemandCard extends StatefulWidget {
  final Demand demand;
  final VoidCallback? onTap;

  const DemandCard({
    super.key,
    required this.demand,
    this.onTap,
  });

  @override
  State<DemandCard> createState() => _DemandCardState();
}

class _DemandCardState extends State<DemandCard> with SingleTickerProviderStateMixin {
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

  String _getTypeDisplayName(String type, String languageCode) {
    switch (type) {
      case 'password_reset': return Translations.getText('security_request', languageCode);
      case 'hardware': return Translations.getText('hardware_support', languageCode);
      case 'administrative': return Translations.getText('admin_request', languageCode);
      case 'custom': return Translations.getText('special_inquiry', languageCode);
      default: 
        if (type.isEmpty) return Translations.getText('general_request', languageCode);
        return type.split('_').map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1)).join(' ');
    }
  }

  String _getStatusDisplayName(String status, String languageCode) {
    switch (status) {
      case 'pending': return Translations.getText('awaiting_review', languageCode);
      case 'in_progress': return Translations.getText('in_process', languageCode);
      case 'resolved': return Translations.getText('completed', languageCode);
      case 'rejected': return Translations.getText('declined', languageCode);
      default: return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orangeAccent;
      case 'in_progress': return Colors.blueAccent;
      case 'resolved': return const Color(0xFF4CAF50);
      case 'rejected': return const Color(0xFFEF5350);
      default: return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'password_reset': return Icons.shield_rounded;
      case 'hardware': return Icons.terminal_rounded;
      case 'administrative': return Icons.description_rounded;
      case 'custom': return Icons.auto_awesome_rounded;
      default: return Icons.help_center_rounded;
    }
  }

  String _formatDate(String dateString, String languageCode) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return '${Translations.getText('today_at', languageCode)} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(widget.demand.status);
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
                if (_isPressed || _hoverController.value > 0)
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.12 * _hoverController.value),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [statusColor.withOpacity(0.2), statusColor.withOpacity(0.05)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Icon(
                                _getIconForType(widget.demand.type),
                                color: statusColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getTypeDisplayName(widget.demand.type, languageCode),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ticket #${(widget.demand.id != null && widget.demand.id!.length >= 8) ? widget.demand.id!.substring(0, 8) : widget.demand.id ?? Translations.getText('unknown', languageCode)}',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusIndicator(statusColor),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.demand.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: AppTheme.accentGold.withOpacity(0.6)),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(widget.demand.createdAt, languageCode),
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.black45,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        _getStatusDisplayName(widget.demand.status, languageCode),
        style: TextStyle(
          color: statusColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
