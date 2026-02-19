import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../localization/translations.dart';

class SettingsController extends ChangeNotifier {
  String _languageCode = 'en';
  bool _notificationsEnabled = true;
  bool _soundEffectsEnabled = true;

  String translate(String key) => Translations.getText(key, _languageCode);

  String get languageCode => _languageCode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEffectsEnabled => _soundEffectsEnabled;

  ThemeMode get themeMode => AppTheme.themeNotifier.value;

  SettingsController() {
    _loadSettings();
    AppTheme.themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppTheme.themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    _languageCode = await SettingsService.getLanguage();
    _notificationsEnabled = await SettingsService.areNotificationsEnabled();
    _soundEffectsEnabled = await SettingsService.areSoundEffectsEnabled();
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    await SettingsService.setLanguage(code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (AppTheme.themeNotifier.value == mode) return;
    
    AppTheme.themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    await SettingsService.setNotificationsEnabled(enabled);
    notifyListeners();
  }

  Future<void> toggleSoundEffects(bool enabled) async {
    _soundEffectsEnabled = enabled;
    await SettingsService.setSoundEffectsEnabled(enabled);
    notifyListeners();
  }
}
