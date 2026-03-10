import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'dart:ui';

class HrDashboardPage extends StatelessWidget {
  const HrDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();
    final isFr = settings.languageCode == 'fr';

    return LuxuryScaffold(
      title: isFr ? 'Espace RH' : 'HR Portal',
      isPremium: true,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr ? 'Gestion des Ressources Humaines' : 'Human Resources Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFr ? 'Supervision complète du personnel et des processus RH.' : 'Complete oversight of staff and HR processes.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 40),
              
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _buildModuleCard(
                    context,
                    title: isFr ? 'Pointage' : 'Attendance',
                    subtitle: isFr ? 'Suivi des présences' : 'Attendance tracking',
                    icon: Icons.access_time_rounded,
                    route: AppRoutes.hrAttendance,
                    isDark: isDark,
                  ),
                  _buildModuleCard(
                    context,
                    title: isFr ? 'Congés' : 'Leave Requests',
                    subtitle: isFr ? 'Gestion des vacances' : 'Vacation management',
                    icon: Icons.beach_access_rounded,
                    route: AppRoutes.hrLeaves,
                    isDark: isDark,
                  ),
                  _buildModuleCard(
                    context,
                    title: isFr ? 'Télétravail' : 'Remote Work',
                    subtitle: isFr ? 'Demandes de télétravail' : 'Remote work requests',
                    icon: Icons.laptop_mac_rounded,
                    route: AppRoutes.hrRemoteWork,
                    isDark: isDark,
                  ),
                  _buildModuleCard(
                    context,
                    title: isFr ? 'Salaires' : 'Salaries',
                    subtitle: isFr ? 'Gestion de paie' : 'Payroll management',
                    icon: Icons.account_balance_wallet_rounded,
                    route: AppRoutes.hrSalaries,
                    isDark: isDark,
                  ),
                  _buildModuleCard(
                    context,
                    title: isFr ? 'Bonus' : 'Bonuses',
                    subtitle: isFr ? 'Récompenses & Primes' : 'Rewards & Perks',
                    icon: Icons.star_rounded,
                    route: AppRoutes.hrBonuses,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    required bool isDark,
  }) {
    final double cardWidth = (MediaQuery.of(context).size.width - 48 - 20) / 2;
    
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: cardWidth > 200 ? cardWidth : double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
             BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A24D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFFC9A24D), size: 28),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
