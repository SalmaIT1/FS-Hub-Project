import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/finance/services/expense_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/core/security/protected_route.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';
import 'add_project_expense_page.dart';

class ProjectExpensesPage extends StatefulWidget {
  const ProjectExpensesPage({super.key});

  @override
  State<ProjectExpensesPage> createState() => _ProjectExpensesPageState();
}

class _ProjectExpensesPageState extends State<ProjectExpensesPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final expenses = await ExpenseService.getAllProjectExpenses();
      final categories = await ExpenseService.getExpenseCategories();
      
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _categories = categories;
          _isLoading = false;
        });
        _fabController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Erreur de Chargement',
          message: 'Impossible de charger les dépenses. Veuillez réessayer.',
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    var filtered = _expenses.where((expense) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = (expense['categorie'] as String).toLowerCase().contains(query) ||
            (expense['description'] as String?)?.toLowerCase().contains(query) == true;
        if (!matchesSearch) return false;
      }
      
      if (_selectedCategory != null) {
        if (expense['category_id'] != _selectedCategory) return false;
      }
      
      if (_startDate != null) {
        final expenseDate = DateTime.parse(expense['date_depense']);
        if (expenseDate.isBefore(_startDate!)) return false;
      }
      
      if (_endDate != null) {
        final expenseDate = DateTime.parse(expense['date_depense']);
        if (expenseDate.isAfter(_endDate!)) return false;
      }
      
      return true;
    }).toList();
    
    // Sort by date (most recent first)
    filtered.sort((a, b) => DateTime.parse(b['date_depense']).compareTo(DateTime.parse(a['date_depense'])));
    
    return filtered;
  }

  double get _totalExpenses {
    return _filteredExpenses.fold(0.0, (sum, expense) => sum + (expense['montant'] as double));
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _showAddExpenseDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProjectExpensePage()),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context, listen: true);

    return ProtectedRoute(
      requiredPermissions: ['manage_project_expenses', 'view_project_expenses'],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: LuxuryAppBar(
          title: settings.translate('project_expenses'),
        ),
        body: _buildBody(settings),
        floatingActionButton: context.hasPermission('manage_project_expenses')
            ? _buildFloatingActionButton(settings)
            : null,
      ),
    );
  }

  Widget _buildBody(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0F0F0F), Colors.black]
              : [const Color(0xFFF8F8F8), const Color(0xFFECECEC)],
        ),
      ),
      child: RefreshIndicator(
        color: AppTheme.accentGold,
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Summary Section
            SliverToBoxAdapter(
              child: _buildSummaryCard(isDark, settings),
            ),
            
            // Filters Section
            SliverToBoxAdapter(
              child: _buildFiltersSection(isDark, settings),
            ),
            
            // Expenses List
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
                  )
                : _filteredExpenses.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState(isDark, settings))
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildExpenseCard(_filteredExpenses[index], isDark, settings);
                            },
                            childCount: _filteredExpenses.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, SettingsController settings) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppTheme.accentGold.withOpacity(0.15), Colors.white.withOpacity(0.05)]
              : [AppTheme.accentGold.withOpacity(0.1), Colors.black.withOpacity(0.02)],
        ),
        border: Border.all(
          color: AppTheme.accentGold.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.translate('total_expenses'),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_totalExpenses.toStringAsFixed(3)} DT',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_filteredExpenses.length} ${settings.translate('expenses')}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(bool isDark, SettingsController settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: [
          // Search bar
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: settings.translate('search_expenses'),
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentGold, size: 20),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Category filter
                _buildCategoryFilter(isDark, settings),
                const SizedBox(width: 8),
                
                // Date range filter
                _buildDateRangeFilter(isDark, settings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark, SettingsController settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _selectedCategory != null 
            ? AppTheme.accentGold.withOpacity(0.2)
            : isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _selectedCategory != null 
              ? AppTheme.accentGold
              : isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: DropdownButton<String>(
        value: _selectedCategory,
        hint: Text(
          settings.translate('all_categories'),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 12,
          ),
        ),
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.accentGold,
          size: 16,
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              settings.translate('all_categories'),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 12,
              ),
            ),
          ),
          ..._categories.map((category) {
            return DropdownMenuItem<String>(
              value: category['id'].toString(),
              child: Text(
                category['nom'],
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              ),
            );
          }),
        ],
        onChanged: (value) {
          setState(() => _selectedCategory = value);
        },
      ),
    );
  }

  Widget _buildDateRangeFilter(bool isDark, SettingsController settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (_startDate != null || _endDate != null)
            ? AppTheme.accentGold.withOpacity(0.2)
            : isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (_startDate != null || _endDate != null)
              ? AppTheme.accentGold
              : isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: _showDateRangePicker,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              color: AppTheme.accentGold,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _getDateRangeText(settings),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateRangeText(SettingsController settings) {
    if (_startDate != null && _endDate != null) {
      return '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}';
    } else if (_startDate != null) {
      return 'Depuis ${_startDate!.day}/${_startDate!.month}';
    } else if (_endDate != null) {
      return 'Jusqu\'au ${_endDate!.day}/${_endDate!.month}';
    }
    return settings.translate('date_range');
  }

  void _showDateRangePicker() {
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? ColorScheme.dark(primary: AppTheme.accentGold)
                : ColorScheme.light(primary: AppTheme.accentGold),
          ),
          child: child!,
        );
      },
    ).then((range) {
      if (range != null) {
        setState(() {
          _startDate = range.start;
          _endDate = range.end;
        });
      }
    });
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense, bool isDark, SettingsController settings) {
    final date = DateTime.parse(expense['date_depense']);
    final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(expense['status'], isDark, settings),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppTheme.accentGold, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense['categorie'] ?? 'Non catégorisé',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (expense['description'] != null && expense['description'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          expense['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(expense['montant'] as double).toStringAsFixed(3)} DT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentGold,
                ),
              ),
            ],
          ),
          
          if (_canApprove(expense)) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApproval(expense['id'], true),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(settings.translate('approve')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      foregroundColor: Colors.green,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApproval(expense['id'], false),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(settings.translate('reject')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status, bool isDark, SettingsController settings) {
    Color color = Colors.grey;
    String label = status ?? 'En attente';
    
    switch (status) {
      case 'pending': 
        color = Colors.orange;
        label = 'En attente';
        break;
      case 'approved_manager':
        color = Colors.blue;
        label = 'Approuvé Manager';
        break;
      case 'approved_hr':
        color = Colors.indigo;
        label = 'Approuvé RH';
        break;
      case 'approved_finance':
        color = Colors.green;
        label = 'Approuvé';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejeté';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  bool _canApprove(Map<String, dynamic> expense) {
    final status = expense['status'];
    final userRole = context.userRole; // Assuming context.userRole exists or similar
    
    if (userRole == 'Admin') return status != 'approved_finance' && status != 'rejected';
    if (userRole == 'Manager' && status == 'pending') return true;
    if (userRole == 'RH' && status == 'approved_manager') return true;
    if (userRole == 'Comptable' && status == 'approved_hr') return true;
    
    return false;
  }

  Future<void> _handleApproval(int id, bool approve) async {
    setState(() => _isLoading = true);
    try {
      final res = approve 
          ? await ExpenseService.approveExpense('project', id)
          : await ExpenseService.rejectExpense('project', id);
      
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: res['success'] == true,
          title: approve ? 'Approbation' : 'Rejet',
          message: res['message'] ?? (approve ? 'Approuvé' : 'Rejeté'),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        LuxuryStatusDialog.show(context, isSuccess: false, title: 'Erreur', message: e.toString());
      }
    }
  }

  Widget _buildEmptyState(bool isDark, SettingsController settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 80,
            color: AppTheme.accentGold.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          Text(
            settings.translate('no_expenses_found'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            settings.translate('add_first_expense'),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(SettingsController settings) {
    return AnimatedBuilder(
      animation: _fabAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 90),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [AppTheme.accentGold, Color(0xFF8B6914)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGold.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              heroTag: 'fab_expenses',
              onPressed: _showAddExpenseDialog,
              backgroundColor: Colors.transparent,
              elevation: 0,
              highlightElevation: 0,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                settings.translate('add_expense'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
