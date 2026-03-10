import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/finance/services/credit_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class CreditsListPage extends StatefulWidget {
  const CreditsListPage({super.key});

  @override
  State<CreditsListPage> createState() => _CreditsListPageState();
}

class _CreditsListPageState extends State<CreditsListPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _creditSummary;
  List<Map<String, dynamic>> _credits = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        CreditService.getCreditSummary(),
        CreditService.getAllCredits(),
      ]);

      final summaryResult = results[0] as Map<String, dynamic>;
      final creditsResult = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _creditSummary = summaryResult['success'] ? summaryResult['data'] : null;
          _credits = creditsResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStatus('Failed to load credits.', success: false);
      }
    }
  }

  void _showStatus(String message, {bool success = true}) {
    LuxuryStatusDialog.show(
      context,
      isSuccess: success,
      title: success ? 'Success' : 'Error',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context);

    return Scaffold(
      appBar: LuxuryAppBar(
        title: settings.translate('credits') ?? 'Credits Management',
        subtitle: 'Capital Allocation & Credit Lines',
        isPremium: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F0F0F), Colors.black]
                : [const Color(0xFFF8F8F8), const Color(0xFFECECEC)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
            : RefreshIndicator(
                color: AppTheme.accentGold,
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
                    if (_creditSummary != null)
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: _buildSummarySection(isDark),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Credit History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    _credits.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No credits found',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildCreditCard(_credits[index], isDark),
                                childCount: _credits.length,
                              ),
                            ),
                          ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.accentGold,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildSummarySection(bool isDark) {
    return Column(
      children: [
        _buildMetricRow(
          isDark: isDark,
          title: 'Total Credits',
          value: '${(_creditSummary!['total_credits'] ?? 0).toStringAsFixed(2)} €',
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricRow(
                isDark: isDark,
                title: 'Used',
                value: '${(_creditSummary!['used_credits'] ?? 0).toStringAsFixed(2)} €',
                icon: Icons.account_balance_rounded,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricRow(
                isDark: isDark,
                title: 'Available',
                value: '${(_creditSummary!['available_credits'] ?? 0).toStringAsFixed(2)} €',
                icon: Icons.savings_rounded,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricRow({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(Map<String, dynamic> credit, bool isDark) {
    final date = DateTime.tryParse(credit['date_credit'] ?? '') ?? DateTime.now();
    final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accentGold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credit['type'] ?? 'Credit Line',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  credit['description'] ?? 'No description',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(credit['montant'] as num).toDouble().toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentGold,
                  fontSize: 16,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blueAccent),
                    onPressed: () => _showAddDialog(credit: credit),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    onPressed: () => _deleteCredit(credit['id']),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDialog({Map<String, dynamic>? credit}) {
    final amountController = TextEditingController(text: credit?['montant']?.toString());
    final descController = TextEditingController(text: credit?['description']);
    final typeController = TextEditingController(text: credit?['type']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(credit == null ? 'New Credit' : 'Edit Credit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount (€)'), keyboardType: TextInputType.number),
            TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Type', hintText: 'e.g. Bank Loan')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'montant': double.tryParse(amountController.text) ?? 0.0,
                'type': typeController.text,
                'description': descController.text,
                'date_credit': credit != null ? credit['date_credit'] : DateTime.now().toIso8601String(),
              };
              
              final result = credit == null
                  ? await CreditService.createCredit(data)
                  : await CreditService.updateCredit(credit['id'], data);
              
              if (mounted) {
                Navigator.pop(context);
                if (result['success']) {
                  _showStatus(result['message']);
                  _loadData();
                } else {
                  _showStatus(result['message'], success: false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCredit(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Credit'),
        content: const Text('Are you sure you want to delete this credit record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await CreditService.deleteCredit(id);
      if (result['success']) {
        _showStatus('Credit deleted');
        _loadData();
      } else {
        _showStatus(result['message'], success: false);
      }
    }
  }
}
