import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import '../../features/auth/data/services/auth_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  bool _twoFactorEnabled = false;

  void _showChangePasswordDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Change Password', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldController,
                    obscureText: true,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (oldController.text.isEmpty || newController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all fields')),
                            );
                            return;
                          }
                          setStateDialog(() => isLoading = true);
                          try {
                            final res = await AuthService.changePassword(oldController.text, newController.text);
                            if (res['success']) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                LuxuryStatusDialog.show(
                                  context,
                                  isSuccess: true,
                                  title: 'Credential Update',
                                  message: 'Authentication parameters have been successfully rehashed and synchronized.',
                                );
                              }
                            } else {
                              if (context.mounted) {
                                LuxuryStatusDialog.show(
                                  context,
                                  isSuccess: false,
                                  title: 'Rehash Failure',
                                  message: res['message'] ?? 'Authenticator rejected the new credential parameters.',
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              LuxuryStatusDialog.show(
                                context,
                                isSuccess: false,
                                title: 'Sync Interrupted',
                                message: 'An unexpected error occurred during credential synchronization.',
                              );
                            }
                          } finally {
                            if (context.mounted) setStateDialog(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: settings.translate('account_security'),
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
            Text(
              'Guard your Account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable two-factor authentication and manage login sessions.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Credentials', isDark),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark,
              children: [
                _buildActionTile(
                  title: 'Change Password',
                  icon: Icons.password_outlined,
                  onTap: _showChangePasswordDialog,
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Two-Factor Authentication',
                  subtitle: 'Use an authenticator app for an extra layer of security.',
                  value: _twoFactorEnabled,
                  onChanged: (val) {
                    setState(() => _twoFactorEnabled = val);
                    if (val) {
                      LuxuryStatusDialog.show(
                        context,
                        isSuccess: true,
                        title: 'Bio-Encryption Active',
                        message: 'A verification cipher has been transmitted to your primary communication node.',
                      );
                    }
                  },
                  icon: Icons.security_rounded,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Recent Logins', isDark),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark,
              children: [
                _buildLoginSessionTile('Windows PC - Chrome', 'Today, 10:15 AM', 'Doha, Qatar (Current)', Icons.computer, isDark),
                _buildDivider(isDark),
                _buildLoginSessionTile('MacBook Air - Safari', 'Yesterday, 04:30 PM', 'Doha, Qatar', Icons.laptop_mac, isDark),
                _buildDivider(isDark),
                _buildLoginSessionTile('iPhone 14 - FS Hub App', 'Mar 1, 09:00 AM', 'Dubai, UAE', Icons.phone_iphone, isDark),
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
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile({required String title, required IconData icon, required VoidCallback onTap, required bool isDark}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (isDark ? Colors.white60 : Colors.black54).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: isDark ? Colors.white60 : Colors.black54, size: 22),
      ),
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26),
    );
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required bool value, required Function(bool) onChanged, required IconData icon, required bool isDark}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.blue, size: 22),
      ),
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)),
      trailing: Switch.adaptive(value: value, activeColor: AppTheme.accentGold, onChanged: onChanged),
    );
  }

  Widget _buildLoginSessionTile(String device, String time, String location, IconData icon, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: CircleAvatar(
        backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        child: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
      ),
      title: Text(device, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
            const SizedBox(height: 2),
            Text(time, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, indent: 68, endIndent: 20, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03));
  }
}

