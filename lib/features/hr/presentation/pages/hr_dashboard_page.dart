import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/routes/app_routes.dart';

class HrDashboardPage extends StatelessWidget {
  const HrDashboardPage({super.key});

  static const _gold = Color(0xFFC9A24D);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    return LuxuryScaffold(
      title: isFr ? 'Espace RH' : 'HR Portal',
      isPremium: true,
      body: Container(
        color: bg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100), // Added to clear the app bar
              // Hero banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFr ? 'Ressources Humaines' : 'Human Resources',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isFr
                                ? 'Présence, congés, paie et gestion du personnel.'
                                : 'Attendance, leave, payroll and workforce management.',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: _gold, size: 30),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                isFr ? 'Modules' : 'Modules',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 14),

              ..._modules(isFr).map((m) => _ModuleTile(
                    icon: m.icon,
                    title: m.title,
                    subtitle: m.subtitle,
                    route: m.route,
                    isDark: isDark,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  List<_Module> _modules(bool isFr) => [
        _Module(
          icon: Icons.person_add_alt_1_rounded,
          title: isFr ? 'Recrutement' : 'Recruitment',
          subtitle: isFr ? 'Documents & génération de contrats' : 'Documents & contract generation',
          route: AppRoutes.hrRecruitment,
        ),
        _Module(
          icon: Icons.access_time_filled_rounded,
          title: isFr ? 'Pointage & Présence' : 'Attendance',
          subtitle: isFr ? 'Suivi quotidien de la présence' : 'Daily attendance tracking',
          route: AppRoutes.hrAttendance,
        ),
        _Module(
          icon: Icons.history_rounded,
          title: isFr ? 'Historique de Présence' : 'Attendance History',
          subtitle: isFr ? 'Vue mensuelle par employé' : 'Monthly view by employee',
          route: AppRoutes.hrAttendanceHistory,
        ),
        _Module(
          icon: Icons.event_available_rounded,
          title: isFr ? 'Gestion des Congés' : 'Leave Requests',
          subtitle: isFr ? 'Demandes et approbations' : 'Requests and approvals',
          route: AppRoutes.hrLeaves,
        ),
        _Module(
          icon: Icons.home_work_rounded,
          title: isFr ? 'Télétravail' : 'Remote Work',
          subtitle: isFr ? 'Demandes de travail à distance' : 'Remote work management',
          route: AppRoutes.hrRemoteWork,
        ),
        _Module(
          icon: Icons.payments_rounded,
          title: isFr ? 'Gestion de Paie' : 'Payroll',
          subtitle: isFr ? 'Salaires et bulletins de paie' : 'Salaries and payslips',
          route: AppRoutes.hrSalaries,
        ),
        _Module(
          icon: Icons.stars_rounded,
          title: isFr ? 'Bonus & Primes' : 'Bonuses',
          subtitle: isFr ? 'Récompenses et incentives' : 'Rewards and incentives',
          route: AppRoutes.hrBonuses,
        ),
        _Module(
          icon: Icons.fact_check_rounded,
          title: isFr ? 'Journaux d\'Audit' : 'Audit Logs',
          subtitle: isFr ? 'Historique des actions système' : 'System activity history',
          route: AppRoutes.hrAuditLogs,
        ),
      ];
}

class _Module {
  final IconData icon;
  final String title, subtitle, route;
  const _Module({required this.icon, required this.title, required this.subtitle, required this.route});
}

class _ModuleTile extends StatefulWidget {
  final IconData icon;
  final String title, subtitle, route;
  final bool isDark;

  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.isDark,
  });

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  bool _hovered = false;
  static const _gold = Color(0xFFC9A24D);

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? const Color(0xFF1A1A1A) : Colors.white;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, widget.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hovered ? _gold.withOpacity(0.04) : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? _gold.withOpacity(0.3)
                  : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: _gold, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(widget.subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _hovered ? _gold : Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
