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
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F7),
      fontFamily: 'NotoColorEmoji',
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentGold,
        brightness: brightness,
        primary: accentGold,
        surface: isDark ? darkCharcoal : Colors.white,
        background: isDark ? Colors.black : const Color(0xFFF5F5F7),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentGold, width: 1),
        ),
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 14),
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        bodyMedium: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 14,
        ),
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
