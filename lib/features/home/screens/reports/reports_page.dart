import 'package:flutter/material.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/features/finance/services/financial_calculation_service.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final summary = await FinancialCalculationService.calculateCompanyFinancialSummary();
      if (mounted) {
        setState(() {
          _summary = summary['success'] ? summary['data'] : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settings = Provider.of<SettingsController>(context);

    return Scaffold(
      appBar: LuxuryAppBar(
        title: settings.translate('reports') ?? 'Reports & Analytics',
        subtitle: 'Executive Overviews & Analytics',
        isPremium: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: isDark
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
            : RefreshIndicator(
                onRefresh: _loadSummary,
                color: AppTheme.accentGold,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildReportCard('OVERALL REVENUE', '${_summary?['total_billed'] ?? 0} €', Icons.trending_up, isDark),
                    const SizedBox(height: 20),
                    _buildReportCard('TOTAL EXPENSES', '${_summary?['total_expenses'] ?? 0} €', Icons.receipt_long, isDark),
                    const SizedBox(height: 20),
                    _buildReportCard('PROFIT MARGIN', '${(((_summary?['total_billed'] ?? 0) - (_summary?['total_expenses'] ?? 0)) / ((_summary?['total_billed'] ?? 1) == 0 ? 1 : (_summary?['total_billed'] ?? 1)) * 100).toStringAsFixed(1)} %', Icons.pie_chart, isDark),
                    const SizedBox(height: 20),
                    _buildTopCategories(isDark),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildReportCard(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.accentGold)),
            ],
          ),
          Icon(icon, size: 48, color: AppTheme.accentGold.withOpacity(0.2)),
        ],
      ),
    );
  }

  Widget _buildTopCategories(bool isDark) {
    final topCategories = _summary?['top_expense_categories'] as List? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EXPENSE DISTRIBUTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
          const SizedBox(height: 20),
          ...topCategories.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c['category'] ?? 'Other', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${(c['percentage'] ?? 0).toStringAsFixed(1)} %', style: const TextStyle(color: AppTheme.accentGold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (c['percentage'] ?? 0) / 100,
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    color: AppTheme.accentGold,
                    minHeight: 12,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
