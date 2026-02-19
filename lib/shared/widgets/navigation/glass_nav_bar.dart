import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/settings_controller.dart';

class GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

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
              children: [
                _buildNavItem(context, 0, Icons.home_rounded, settings.translate('home')),
                _buildNavItem(context, 1, Icons.badge_rounded, settings.languageCode == 'fr' ? 'Équipe' : 'Team'),
                _buildNavItem(context, 2, Icons.assignment_rounded, settings.translate('demands')),
                _buildNavItem(context, 3, Icons.chat_bubble_rounded, settings.translate('chat')),
                _buildNavItem(context, 4, Icons.person_rounded, settings.translate('profile')),
              ],
            ),
          ),
        ),
      ),
    );
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
