import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/finance/services/expense_service.dart';
import 'package:fs_hub/features/finance/services/financial_calculation_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class ExpensesListPage extends StatefulWidget {
  const ExpensesListPage({super.key});

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _companySummary;
  List<Map<String, dynamic>> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FinancialCalculationService.calculateCompanyFinancialSummary(),
        ExpenseService.getAllProjectExpenses(),
        ExpenseService.getAllCompanyExpenses(),
      ]);

      final companySummaryResult = results[0] as Map<String, dynamic>;
      final projectExpenses = results[1] as List<Map<String, dynamic>>;
      final companyExpenses = results[2] as List<Map<String, dynamic>>;

      // Merge and sort expenses by date
      List<Map<String, dynamic>> allExpenses = [...projectExpenses, ...companyExpenses];
      allExpenses.sort((a, b) {
        final dateA = DateTime.tryParse(a['date_depense'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['date_depense'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA); // Newest first
      });

      if (mounted) {
        setState(() {
          _companySummary = companySummaryResult['success'] ? companySummaryResult['data'] : null;
          _expenses = allExpenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStatus('Failed to load expenses.', success: false);
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
        title: settings.translate('expenses') ?? 'Expenses Management',
        subtitle: 'Operational Spending & Budget Control',
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
                    if (_companySummary != null)
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: _buildSummarySection(isDark, settings),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    _expenses.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No expenses found',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildExpenseCard(_expenses[index], isDark),
                                childCount: _expenses.length,
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

  Widget _buildSummarySection(bool isDark, SettingsController settings) {
    final totalExpenses = _companySummary!['total_expenses'] as double? ?? 0.0;
    final averageMonthly = _companySummary!['average_monthly'] as double? ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSimpleMetricCard(
                isDark: isDark,
                title: 'Total Expenses',
                value: '${totalExpenses.toStringAsFixed(3)} DT',
                icon: Icons.receipt_long_rounded,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleMetricCard(
                isDark: isDark,
                title: 'Monthly Avg',
                value: '${averageMonthly.toStringAsFixed(3)} DT',
                icon: Icons.trending_up_rounded,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleMetricCard({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense, bool isDark) {
    final date = DateTime.tryParse(expense['date_depense'] ?? '') ?? DateTime.now();
    final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final isSalary = expense['categorie'] == 'RH/Salaires';

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
              color: (isSalary ? Colors.blue : AppTheme.accentGold).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSalary ? Icons.person_pin_rounded : Icons.receipt_rounded,
              color: isSalary ? Colors.blue : AppTheme.accentGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense['categorie'] ?? 'General Expense',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  expense['description'] ?? 'No description',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
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
                '${(expense['montant'] as num).toDouble().toStringAsFixed(3)} DT',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  fontSize: 16,
                ),
              ),
              if (!isSalary)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blueAccent),
                      onPressed: () => _showAddDialog(expense: expense),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      onPressed: () => _deleteExpense(expense['id']),
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

  void _showAddDialog({Map<String, dynamic>? expense}) {
    final amountController = TextEditingController(text: expense?['montant']?.toString());
    final descController = TextEditingController(text: expense?['description']);
    final categoryController = TextEditingController(text: expense?['categorie']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense == null ? 'New Expense' : 'Edit Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount (DT)'), keyboardType: TextInputType.number),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Supplies')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'montant': double.tryParse(amountController.text) ?? 0.0,
                'categorie': categoryController.text,
                'description': descController.text,
                'date_depense': expense != null ? expense['date_depense'] : DateTime.now().toIso8601String(),
              };
              
              final result = expense == null
                  ? await ExpenseService.createProjectExpense(data)
                  : await ExpenseService.updateProjectExpense(expense['id'], data);
              
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

  Future<void> _deleteExpense(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ExpenseService.deleteProjectExpense(id);
      if (result['success']) {
        _showStatus('Expense deleted');
        _loadData();
      } else {
        _showStatus(result['message'], success: false);
      }
    }
  }
}
