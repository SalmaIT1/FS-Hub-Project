import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/state/settings_controller.dart';
import '../shared/widgets/luxury/luxury_app_bar.dart';
import '../core/theme/app_theme.dart';
import '../theme/design_tokens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: settings.translate('settings'),
      showBackButton: true,
      onBackPress: () => Navigator.pop(context),
      isPremium: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _buildSectionHeader(
              settings.translate('appearance'),
              isDark,
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark,
              children: [
                _buildThemeTile(context, settings, isDark),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(
              settings.translate('language'),
              isDark,
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark,
              children: [
                _buildLanguageTile(context, settings, isDark),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(
              settings.translate('notifications') + ' & ' + (settings.languageCode == 'fr' ? 'Sons' : 'Sounds'),
              isDark,
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark,
              children: [
                _buildSwitchTile(
                  context,
                  title: settings.translate('push_notifications'),
                  subtitle: settings.languageCode == 'fr' ? 'Recevoir des alertes pour les nouveaux messages' : 'Receive alerts for new messages',
                  value: settings.notificationsEnabled,
                  onChanged: (val) => settings.toggleNotifications(val),
                  icon: Icons.notifications_none_rounded,
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  context,
                  title: settings.translate('sound_effects'),
                  subtitle: settings.languageCode == 'fr' ? 'Jouer des sons pour les actions' : 'Play sounds for actions',
                  value: settings.soundEffectsEnabled,
                  onChanged: (val) => settings.toggleSoundEffects(val),
                  icon: Icons.volume_up_outlined,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(
              settings.translate('account'),
              isDark,
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark,
              children: [
                _buildActionTile(
                  context,
                  title: settings.languageCode == 'fr' ? 'Sécurité du compte' : 'Account Security',
                  icon: Icons.security_outlined,
                  onTap: () {},
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  context,
                  title: settings.translate('privacy'),
                  icon: Icons.lock_outline_rounded,
                  onTap: () {},
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(
              settings.translate('support'),
              isDark,
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark,
              children: [
                _buildActionTile(
                  context,
                  title: settings.translate('help_center'),
                  icon: Icons.help_outline_rounded,
                  onTap: () {},
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  context,
                  title: settings.translate('report_issue'),
                  icon: Icons.bug_report_outlined,
                  onTap: () {},
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  context,
                  title: settings.translate('clear_cache'),
                  icon: Icons.delete_outline_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(settings.languageCode == 'fr' ? 'Cache vidé' : 'Cache cleared')),
                    );
                  },
                  isDark: isDark,
                  textColor: Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 48),
            Center(
              child: Text(
                'FS Hub v1.2.0',
                style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 100), // Space for bottom nav or just breathing room
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFB8860B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, SettingsController settings, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          settings.themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          color: AppTheme.accentGold,
          size: 22,
        ),
      ),
      title: Text(
        settings.languageCode == 'fr' ? 'Thème' : 'Theme',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<ThemeMode>(
          value: settings.themeMode,
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: [
            DropdownMenuItem(
              value: ThemeMode.dark,
              child: Text(
                settings.languageCode == 'fr' ? 'Sombre' : 'Dark',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
              ),
            ),
            DropdownMenuItem(
              value: ThemeMode.light,
              child: Text(
                settings.languageCode == 'fr' ? 'Clair' : 'Light',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
              ),
            ),
            DropdownMenuItem(
              value: ThemeMode.system,
              child: Text(
                settings.languageCode == 'fr' ? 'Système' : 'System',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
              ),
            ),
          ],
          onChanged: (mode) {
            if (mode != null) settings.setThemeMode(mode);
          },
        ),
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, SettingsController settings, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.language_rounded,
          color: Colors.blue,
          size: 22,
        ),
      ),
      title: Text(
        settings.languageCode == 'fr' ? 'Langue de l\'application' : 'App Language',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: settings.languageCode,
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: const [
            DropdownMenuItem(
              value: 'en',
              child: Text(
                'English',
                style: TextStyle(fontSize: 14),
              ),
            ),
            DropdownMenuItem(
              value: 'fr',
              child: Text(
                'Français',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
          onChanged: (code) {
            if (code != null) settings.setLanguage(code);
          },
        ),
      ),
    );
  }

  Widget _buildSwitchTile(BuildContext context,
      {required String title,
      required String subtitle,
      required bool value,
      required Function(bool) onChanged,
      required IconData icon,
      required bool isDark}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.orange,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 12,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeColor: AppTheme.accentGold,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile(BuildContext context,
      {required String title,
      required IconData icon,
      required VoidCallback onTap,
      required bool isDark,
      Color? textColor}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (textColor ?? (isDark ? Colors.white60 : Colors.black54)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: textColor ?? (isDark ? Colors.white60 : Colors.black54),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? (isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 20,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
    );
  }
}
