import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/settings_controller.dart';
import '../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/data/services/auth_service.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _profileVisible = true;
  bool _showOnlineStatus = true;
  bool _analyticsEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final res = await AuthService.getUserSettings();
    if (res['success'] && res['data'] != null) {
      final data = res['data'];
      setState(() {
        _profileVisible = data['profile_visible'] ?? true;
        _showOnlineStatus = data['show_online_status'] ?? true;
        _analyticsEnabled = data['analytics_enabled'] ?? false;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    await AuthService.updateUserSettings({
      'profile_visible': _profileVisible,
      'show_online_status': _showOnlineStatus,
      'analytics_enabled': _analyticsEnabled,
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: settings.translate('privacy'),
      showBackButton: true,
      onBackPress: () => Navigator.pop(context),
      isPremium: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
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
                  Text(
                    'Manage Your Privacy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Control who sees your activity and how we use your data.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Visibility', isDark),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    isDark,
                    children: [
                      _buildSwitchTile(
                        title: 'Profile Visibility',
                        subtitle: 'Allow other employees to see your contact info',
                        value: _profileVisible,
                        onChanged: (val) {
                          setState(() => _profileVisible = val);
                          _saveSettings();
                        },
                        icon: Icons.visibility_outlined,
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSwitchTile(
                        title: 'Online Status',
                        subtitle: 'Show when you are active on the portal',
                        value: _showOnlineStatus,
                        onChanged: (val) {
                          setState(() => _showOnlineStatus = val);
                          _saveSettings();
                        },
                        icon: Icons.circle_outlined,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Data Usage', isDark),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    isDark,
                    children: [
                      _buildSwitchTile(
                        title: 'Analytics & Usage',
                        subtitle: 'Share anonymous usage data to help us improve',
                        value: _analyticsEnabled,
                        onChanged: (val) {
                          setState(() => _analyticsEnabled = val);
                          _saveSettings();
                        },
                        icon: Icons.analytics_outlined,
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildActionTile(
                        title: 'Request My Data',
                        icon: Icons.download_outlined,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('A request has been sent to the IT admin team.')),
                          );
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
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
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
              ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
      required String title,
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
          color: AppTheme.accentGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.accentGold, size: 22),
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
        style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeColor: AppTheme.accentGold,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile({
      required String title,
      required IconData icon,
      required VoidCallback onTap,
      required bool isDark}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white60 : Colors.black54).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isDark ? Colors.white60 : Colors.black54, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26),
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
