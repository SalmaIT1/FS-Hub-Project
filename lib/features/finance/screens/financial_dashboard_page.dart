import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/features/finance/services/finance_service.dart';

class FinancialDashboardPage extends StatefulWidget {
  const FinancialDashboardPage({super.key});

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage> {
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  final currencyFormat = NumberFormat.currency(symbol: '€', decimalDigits: 0);

  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    final summary = await FinanceService.getFinanceSummary();
    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    return LuxuryScaffold(
      title: isFr ? 'Finances' : 'Finance Center',
      subtitle: isFr ? 'Rendement & Trésorerie' : 'Yield & Treasury',
      isPremium: true,
      body: Container(
        color: bg,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : RefreshIndicator(
                onRefresh: _loadSummary,
                color: _gold,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 100), // Space for LuxuryAppBar since it's floating
                      _buildMainBalanceCard(isDark, isFr),
                      const SizedBox(height: 28),
                      _buildQuickActionGrid(context, isFr),
                      const SizedBox(height: 32),
                      _buildDistributionSection(isDark, isFr),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMainBalanceCard(bool isDark, bool isFr) {
    final netProfit = double.tryParse(_summary['net_profit']?.toString() ?? '0') ?? 0.0;
    final totalPaid = double.tryParse(_summary['total_paid']?.toString() ?? '0') ?? 0.0;
    final expenses = double.tryParse(_summary['total_expenses']?.toString() ?? '0') ?? 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFr ? 'SOLDE NET' : 'NET BALANCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _gold.withOpacity(0.8),
                        letterSpacing: 2.0,
                      ),
                    ),
                    const Icon(Icons.show_chart_rounded, color: Colors.green, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormat.format(netProfit),
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFr ? 'Trésorerie Actuelle' : 'Current Liquidity',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                _buildMiniStat(isFr ? 'Collecté' : 'Collected', currencyFormat.format(totalPaid), Colors.green),
                Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.2)),
                _buildMiniStat(isFr ? 'Dépenses' : 'Expenses', currencyFormat.format(expenses), Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid(BuildContext context, bool isFr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFr ? 'OPÉRATIONS RAPIDES' : 'QUICK ACTIONS',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ActionItem(
              icon: Icons.description_rounded,
              label: isFr ? 'Factures' : 'Invoices',
              onTap: () => Navigator.pushNamed(context, '/invoices'),
              color: Colors.blueAccent,
            ),
            const SizedBox(width: 12),
            _ActionItem(
              icon: Icons.receipt_long_rounded,
              label: isFr ? 'Dépenses' : 'Expenses',
              onTap: () => Navigator.pushNamed(context, '/expenses'),
              color: Colors.orangeAccent,
            ),
            const SizedBox(width: 12),
            _ActionItem(
              icon: Icons.auto_graph_rounded,
              label: isFr ? 'Crédits' : 'Credits',
              onTap: () => Navigator.pushNamed(context, '/credits'),
              color: _gold,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDistributionSection(bool isDark, bool isFr) {
    final distribution = (_summary['status_distribution'] as List? ?? []);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFr ? 'ÉTAT DES FACTURES' : 'INVOICE STATUS',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (distribution.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Aucune donnée disponible', style: TextStyle(color: Colors.grey))),
          )
        else
          ...distribution.map((s) => _buildStatusCard(s, isDark, isFr)),
      ],
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> status, bool isDark, bool isFr) {
    final name = status['statut'] ?? 'Unknown';
    final count = status['count'] ?? 0;
    final amount = double.tryParse(status['amount']?.toString() ?? '0') ?? 0.0;
    
    Color statusColor = _gold;
    if (name.toLowerCase().contains('payée')) statusColor = Colors.green;
    if (name.toLowerCase().contains('annul')) statusColor = Colors.red;
    if (name.toLowerCase().contains('retard')) statusColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.folder_shared_rounded, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${isFr ? 'factures' : 'invoices'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  State<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<_ActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _isHovered = h),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: _isHovered 
                ? widget.color.withOpacity(0.1) 
                : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered 
                  ? widget.color.withOpacity(0.4) 
                  : (isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
            ),
          ),
          child: Column(
            children: [
              Icon(widget.icon, color: widget.color, size: 28),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
