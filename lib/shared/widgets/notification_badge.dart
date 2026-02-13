import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  final int notificationCount;
  final VoidCallback? onTap;
  final Color? badgeColor;
  final Color? textColor;

  const NotificationBadge({
    Key? key,
    required this.notificationCount,
    this.onTap,
    this.badgeColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications,
              size: 28,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.grey[700],
            ),
            if (notificationCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFFD4AF37), // Gold accent color
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1), // Stronger contrast
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    notificationCount > 99 ? '99+' : notificationCount.toString(),
                    style: TextStyle(
                      color: textColor ?? Colors.black, // Black text for gold badge
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}