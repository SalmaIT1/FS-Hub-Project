import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const Color accentGold = Color(0xFFC9A24D); // Changed to match Premium theme better
  static const Color darkCharcoal = Color(0xFF121212);
  static const String _themeKey = 'theme_mode';
  
  // Theme Toggle Notifier
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex != null) {
      themeNotifier.value = ThemeMode.values[themeIndex];
    }
  }

  static Future<void> toggleTheme() async {
    final current = themeNotifier.value;
    final next = current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    themeNotifier.value = next;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, next.index);
  }

  static ThemeData get glassDarkTheme => _buildTheme(Brightness.dark);
  static ThemeData get glassLightTheme => _buildTheme(Brightness.light);
  
  static TextStyle get bodyText => const TextStyle(
    fontSize: 14,
    color: Colors.white70,
  );

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark ? accentGold : const Color(0xFFB8860B); // Darker gold for light mode contrast
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FB), // Crisp but not stark
      fontFamily: 'NotoColorEmoji',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B4513), 
        surface: isDark ? darkCharcoal : Colors.white,
        onSurface: isDark ? Colors.white : const Color(0xFF101828), // Deeper contrast
        background: isDark ? Colors.black : const Color(0xFFEDF2F7), // More depth
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF101828)),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF101828),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white, // Pure white for light mode fields
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2.0), // Thicker focus
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF475467), 
          fontSize: 14,
          fontWeight: FontWeight.w600
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white24 : const Color(0xFF98A2B3), 
          fontSize: 14
        ),
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF101828),
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF101828),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF101828),
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        bodyMedium: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF1D2939), // Richer dark
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF475467),
          fontSize: 13,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkCharcoal : Colors.white,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      primaryTextTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14),
      ).copyWith(
        bodyLarge: const TextStyle(fontSize: 16),
        bodyMedium: const TextStyle(fontSize: 14),
        bodySmall: const TextStyle(fontSize: 12),
      ),
    );
  }
}
