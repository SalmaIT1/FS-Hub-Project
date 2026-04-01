import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/salary_model.dart';
import 'package:intl/intl.dart';

class HrSalariesPage extends StatefulWidget {
  const HrSalariesPage({super.key});

  @override
  State<HrSalariesPage> createState() => _HrSalariesPageState();
}

class _HrSalariesPageState extends State<HrSalariesPage> {
  List<Salary> _salaries = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await HrService.getSalaries();
      // Filter for showing currently selected month (best effort in UI)
      if (mounted) {
        setState(() {
          _salaries = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePayroll() async {
    final isFr = context.read<SettingsController>().languageCode == 'fr';
    final monthStr = DateFormat('yyyy-MM').format(_selectedDate);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFr ? 'Générer la paie' : 'Generate Payroll'),
        content: Text(isFr 
          ? 'Voulez-vous générer automatiquement la paie pour le mois de $monthStr ?\n\nCela inclura les salaires de base, les primes du mois et les déductions pour congés (si > 21j).'
          : 'Do you want to automatically generate payroll for $monthStr?\n\nThis will include base salaries, monthly bonuses, and leave deductions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Oui', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await HrService.bulkGenerateSalaries(monthStr);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? (isFr ? 'Paie générée avec succès !' : 'Payroll generated successfully!')
            : (isFr ? 'Échec de la génération.' : 'Generation failed.')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    // Filter current month salaries
    final monthStr = DateFormat('yyyy-MM').format(_selectedDate);
    final currentSalaries = _salaries.where((s) => DateFormat('yyyy-MM').format(s.salaryMonth) == monthStr).toList();

    double totalNet = 0;
    double totalBonuses = 0;
    double totalDeductions = 0;
    for (final s in currentSalaries) {
      totalNet += (s.netSalary ?? 0.0);
      totalBonuses += (s.bonusAmount ?? 0.0);
      totalDeductions += (s.deductions ?? 0.0);
    }

    return LuxuryScaffold(
      title: isFr ? 'Gestion de Paie' : 'Payroll',
      showBackButton: true,
      actions: [
        IconButton(
          onPressed: _generatePayroll,
          icon: const Icon(Icons.auto_fix_high_rounded, color: _gold),
          tooltip: isFr ? 'Générer' : 'Generate',
        )
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : SafeArea(
              child: Container(
              color: bg,
              child: Column(
                children: [
                  // Month Picker Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: _gold, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat.yMMMM(isFr ? 'fr' : 'en').format(_selectedDate).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 16),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  // Summary metrics
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      children: [
                        _StatCard(
                          label: isFr ? 'Masse Nette' : 'Net Mass',
                          value: '${totalNet.toStringAsFixed(0)} DH',
                          color: _gold,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: isFr ? 'Bonus' : 'Bonuses',
                          value: '+${totalBonuses.toStringAsFixed(0)}',
                          color: Colors.green,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: isFr ? 'Déductions' : 'Deductions',
                          value: '-${totalDeductions.toStringAsFixed(0)}',
                          color: Colors.redAccent,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // List
                  Expanded(
                    child: currentSalaries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.payments_outlined, size: 56, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  isFr ? 'Aucune fiche pour ce mois' : 'No records for this month',
                                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                            itemCount: currentSalaries.length,
                            itemBuilder: (_, i) => _SalaryCard(salary: currentSalaries[i], isDark: isDark, isFr: isFr),
                          ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;

  const _StatCard({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  final Salary salary;
  final bool isDark, isFr;

  static const _gold = Color(0xFFC9A24D);

  const _SalaryCard({required this.salary, required this.isDark, required this.isFr});

  Color get _statusColor {
    switch (salary.paymentStatus) {
      case 'paid':      return const Color(0xFF22C55E);
      case 'cancelled': return const Color(0xFFEF4444);
      default:          return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline_rounded, color: _gold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employé #${salary.employeeId.substring(0, 8)}...',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Matricule: ${salary.paymentStatus.toUpperCase()}',
                      style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                    '${(salary.netSalary ?? 0).toStringAsFixed(0)} DH',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _gold),
                  ),
                  Text(
                    isFr ? 'Net à payer' : 'Net Salary',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailItem(label: isFr ? 'Base' : 'Base', value: '${salary.baseSalary.toStringAsFixed(0)}'),
              _DetailItem(label: 'Bonus', value: '+${(salary.bonusAmount ?? 0).toStringAsFixed(0)}', color: Colors.green),
              _DetailItem(label: 'Deduc.', value: '-${(salary.deductions ?? 0).toStringAsFixed(0)}', color: Colors.redAccent),
            ],
          )
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _DetailItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }
}
