import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: settings.translate('help_center'),
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
            _buildSearchAndHeader(isDark),
            const SizedBox(height: 32),
            _buildSectionTitle('Frequently Asked Questions', isDark),
            const SizedBox(height: 16),
            _buildFAQTile(
              'How to reset my password?',
              'You can request a password reset from the login screen or navigate to Settings > Account Security to change it.',
              isDark,
            ),
            _buildFAQTile(
              'Where can I find employee documents?',
              'Go to the "Employees" tab from the main menu and select the corresponding employee profile to view their uploaded files.',
              isDark,
            ),
            _buildFAQTile(
              'Who approves my leaves or demands?',
              'Demands and leaves are processed by the HR department and will be visible under the "Demands" tab once updated by an admin.',
              isDark,
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Contact Support', isDark),
            const SizedBox(height: 16),
            _buildContactTile(
              Icons.email_outlined,
              'Email Support',
              'support@fshub.com',
              isDark,
            ),
            _buildContactTile(
              Icons.phone_outlined,
              'Call Us',
              '+1 (800) 123-4567',
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How can we help you?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: TextField(
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search for articles...',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              prefixIcon: Icon(Icons.search, color: AppTheme.accentGold),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFB8860B),
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        ),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppTheme.accentGold,
          collapsedIconColor: isDark ? Colors.white54 : Colors.black45,
          title: Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              answer,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(IconData icon, String title, String subtitle, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.accentGold, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

