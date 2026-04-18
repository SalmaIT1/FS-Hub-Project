import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';

class GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<Map<String, dynamic>> items;

  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();
    
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
      height: 70,
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.08) 
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.12) 
              : Colors.black.withOpacity(0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final route = item['route'] as String?;
                final title = item['title'] as String?;
                final iconName = item['icon'] as String?;

                final label = title ?? (route == '/' ? settings.translate('home') : '');
                final icon = _iconForName(iconName);
                return _buildNavItem(context, index, icon, label);
              }),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForName(String? iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home_rounded;
      case 'people':
        return Icons.badge_rounded;
      case 'assignment':
        return Icons.task_alt_rounded;
      case 'description':
        return Icons.assignment_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'settings':
        return Icons.settings_rounded;
      default:
        return Icons.home_rounded;
    }
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = const Color(0xFFD4AF37); // Gold accent
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? activeColor.withOpacity(0.15) 
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? activeColor 
                    : (isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.4)),
                size: isSelected ? 26 : 24,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

