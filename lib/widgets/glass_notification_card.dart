import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GlassNotificationCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime parsedTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    final String formattedTime = DateFormat('HH:mm').format(parsedTime);
    final String formattedDate = DateFormat('MMM dd').format(parsedTime);

    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark 
            ? Colors.white.withValues(alpha: 0.05) 
            : Colors.black.withValues(alpha: 0.03),
        border: Border.all(
          color: isDark 
              ? (isRead ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFFFD700).withValues(alpha: 0.3))
              : (isRead ? Colors.black.withValues(alpha: 0.05) : const Color(0xFFFFD700).withValues(alpha: 0.4)),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: [
          if (!isRead)
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Type icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getIconBackgroundColor(type, isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIconForType(type),
                        size: 18,
                        color: _getIconColor(type, isDark),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark 
                                  ? (isRead ? Colors.white70 : Colors.white)
                                  : (isRead ? Colors.black54 : Colors.black87),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Message
                          Text(
                            message,
                            style: TextStyle(
                              color: isDark 
                                  ? Colors.white60
                                  : Colors.black45,
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Timestamp and mark as read
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: isDark 
                                ? Colors.white54
                                : Colors.black45,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: isDark 
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.35),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Unread indicator and mark as read button
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: onMarkAsRead,
                        icon: Icon(
                          Icons.done,
                          size: 16,
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3),
                        ),
                        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                        padding: EdgeInsets.zero,
                        style: ButtonStyle(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Color _getIconBackgroundColor(String type, bool isDark) {
    switch (type) {
      case 'demand':
        return const Color(0xFFFFD700).withValues(alpha: 0.15);
      case 'system':
        return isDark 
            ? Colors.blue.withValues(alpha: 0.15)
            : Colors.blue.shade100;
      default:
        return isDark 
            ? Colors.grey.withValues(alpha: 0.15)
            : Colors.grey.shade100;
    }
  }

  Color _getIconColor(String type, bool isDark) {
    switch (type) {
      case 'demand':
        return const Color(0xFFFFD700);
      case 'system':
        return isDark 
            ? Colors.blue.shade300
            : Colors.blue.shade600;
      default:
        return isDark 
            ? Colors.grey.shade300
            : Colors.grey.shade600;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'demand':
        return Icons.assignment_outlined;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }
}