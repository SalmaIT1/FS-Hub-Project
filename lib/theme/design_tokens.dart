import 'package:flutter/material.dart';

class DesignTokens {
  // Colors
  static const Color baseDark = Color(0xFF0A0A0A);
  static const Color surfaceGlass = Color(0xFF1A1A1A);
  static const Color accentGold = Color(0xFFC9A24D);
  static const Color textLight = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF888888);
  
  // Spacing
  static const double spacingXs = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXl = 32;
  
  // Radius
  static const double radiusS = 12;
  static const double radiusM = 20;
  static const double radiusL = 28;
  
  // Blur
  static const double blurIntensity = 20;
  
  // Typography
  static const TextStyle headingL = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textLight,
    height: 1.2,
  );
  
  static const TextStyle headingM = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textLight,
    height: 1.3,
  );
  
  static const TextStyle headingS = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textLight,
    height: 1.3,
  );
  
  static const TextStyle bodyL = TextStyle(
    fontSize: 16,
    color: textLight,
    height: 1.5,
  );
  
  static const TextStyle bodyM = TextStyle(
    fontSize: 14,
    color: textSecondary,
    height: 1.4,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textSecondary,
    height: 1.3,
  );
  
  // Shadows
  static final List<BoxShadow> glassShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}