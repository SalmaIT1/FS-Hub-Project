import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/finance/services/financial_calculation_service.dart';
import 'package:fs_hub/features/finance/services/expense_service.dart';
import 'package:fs_hub/features/projects/services/project_service.dart';
import 'package:fs_hub/shared/models/project_model.dart';
import 'package:fs_hub/features/finance/services/credit_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/core/security/permission_guard.dart';
import 'package:fs_hub/core/security/protected_route.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class FinancialDashboardPage extends StatefulWidget {
  final int initialTab;
  const FinancialDashboardPage({super.key, this.initialTab = 0});

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  List<Project> _projects = [];
  Map<String, dynamic>? _companySummary;
  bool _isLoading = true;
  List<Map<String, dynamic>> _projectFinancialSummaries = [];
  late AnimationController _refreshController;
  late Animation<double> _refreshAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _refreshAnimation = CurvedAnimation(
      parent: _refreshController,
      curve: Curves.easeInOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Charger les données en parallèle
      final results = await Future.wait([
        ProjectService.getAllProjects(),
        FinancialCalculationService.calculateCompanyFinancialSummary(),
      ]);
      
      final projects = results[0] as List<Project>;
      final companySummary = results[1] as Map<String, dynamic>;
      
      // Calculer les résumés financiers pour chaque projet
      final projectSummaries = <Map<String, dynamic>>[];
      for (final project in projects) {
        if (project.id != null) {
          final summary = await FinancialCalculationService.calculateProjectFinancialSummary(project.id!);
          if (summary['success']) {
            projectSummaries.add(summary['data']);
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _projects = projects;
          _companySummary = companySummary['success'] ? companySummary['data'] : null;
          _projectFinancialSummaries = projectSummaries;
          _isLoading = false;
        });
        _refreshController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Erreur de Chargement',
          message: 'Impossible de charger les données financières. Veuillez réessayer.',
        );
      }
    }
  }

  Future<void> _refreshData() async {
    _refreshController.reset();
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context, listen: true);

    return ProtectedRoute(
      requiredPermissions: ['view_financial_reports', 'view_revenue'],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: LuxuryAppBar(
          title: settings.translate('financial_dashboard') ?? 'Financial Dashboard',
          subtitle: 'Executive Summary & Project Yield',
          isPremium: true,
        ),
        body: _buildBody(settings),
        floatingActionButton: _buildRefreshButton(settings),
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
      child: Column(
        children: [
          // Header with refresh
          _buildHeader(settings),
          
          // Tabs
          _buildTabs(settings),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: [
                _buildOverviewTab(settings),
                _buildProjectsTab(settings),
                _buildExpensesTab(settings),
                _buildCreditsTab(settings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                settings.translate('financial_overview'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              AnimatedBuilder(
                animation: _refreshAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _refreshAnimation.value * 0.5 * 3.14159,
                    child: Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.accentGold,
                      size: 24,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Vue d\'ensemble de la santé financière de l\'entreprise et des projets',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: TabBar(
        controller: _tabController!,
        labelColor: isDark ? Colors.white70 : Colors.black87,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500),
        indicatorColor: AppTheme.accentGold,
        indicatorWeight: 3,
        tabs: [
          Tab(
            text: settings.translate('overview'),
            icon: const Icon(Icons.dashboard_rounded),
          ),
          Tab(
            text: settings.translate('projects'),
            icon: const Icon(Icons.work_outline_rounded),
          ),
          Tab(
            text: settings.translate('expenses'),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
          Tab(
            text: settings.translate('credits'),
            icon: const Icon(Icons.account_balance_wallet_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentGold),
      );
    }
    
    return RefreshIndicator(
      color: AppTheme.accentGold,
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Company Summary Cards
            _buildCompanySummaryCards(isDark, settings),
            
            const SizedBox(height: 24),
            
            // Project Overview
            _buildProjectOverviewCards(isDark, settings),
            
            const SizedBox(height: 24),
            
            // Quick Stats
            _buildQuickStats(isDark, settings),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanySummaryCards(bool isDark, SettingsController settings) {
    if (_companySummary == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
        ),
        child: Center(
          child: Text(
            'Aucune donnée disponible',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      );
    }
    
    final totalExpenses = _companySummary!['total_expenses'] as double;
    final averageMonthly = _companySummary!['average_monthly'] as double;
    final topCategories = List<Map<String, dynamic>>.from(_companySummary!['top_expense_categories'] ?? []);
    
    return Column(
      children: [
        // Total Expenses Card
        _buildMetricCard(
          isDark: isDark,
          title: 'Total des Dépenses',
          value: '${totalExpenses.toStringAsFixed(2)} €',
          icon: Icons.euro_rounded,
          color: totalExpenses > 10000 ? Colors.red : AppTheme.accentGold,
          subtitle: 'Toutes catégories',
        ),
        
        const SizedBox(height: 16),
        
        // Monthly Average Card
        _buildMetricCard(
          isDark: isDark,
          title: 'Moyenne Mensuelle',
          value: '${averageMonthly.toStringAsFixed(2)} €',
          icon: Icons.trending_up_rounded,
          color: Colors.blue,
          subtitle: 'Basé sur 30 derniers jours',
        ),
        
        const SizedBox(height: 16),
        
        // Top Categories
        _buildTopCategoriesCard(isDark, settings, topCategories),
      ],
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoriesCard(bool isDark, SettingsController settings, List<Map<String, dynamic>> topCategories) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Catégories',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...topCategories.map((category) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    category['category'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Text(
                  '${(category['amount'] as double).toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  '${(category['percentage'] as double).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildProjectOverviewCards(bool isDark, SettingsController settings) {
    final activeProjects = _projects.where((p) => p.statut == 'actif' || p.statut == 'En cours').length;
    final totalBudget = _projectFinancialSummaries.fold(
      0.0, 
      (sum, summary) => sum + (summary['estimation_budget'] as num).toDouble()
    );
    final totalExpenses = _projectFinancialSummaries.fold(
      0.0, 
      (sum, summary) => sum + (summary['total_expenses'] as num).toDouble()
    );
    
    return Column(
      children: [
        _buildMetricCard(
          isDark: isDark,
          title: 'Projets Actifs',
          value: '$activeProjects',
          icon: Icons.work_outline_rounded,
          color: Colors.green,
          subtitle: 'En cours',
        ),
        
        const SizedBox(height: 16),
        
        _buildMetricCard(
          isDark: isDark,
          title: 'Budget Total',
          value: '${totalBudget.toStringAsFixed(2)} €',
          icon: Icons.account_balance_rounded,
          color: AppTheme.accentGold,
          subtitle: 'Estimations',
        ),
        
        const SizedBox(height: 16),
        
        _buildMetricCard(
          isDark: isDark,
          title: 'Dépenses Totales',
          value: '${totalExpenses.toStringAsFixed(2)} €',
          icon: Icons.receipt_long_rounded,
          color: totalExpenses > totalBudget ? Colors.red : AppTheme.accentGold,
          subtitle: 'Tous projets',
        ),
      ],
    );
  }

  Widget _buildQuickStats(bool isDark, SettingsController settings) {
    final profitableProjects = _projectFinancialSummaries.where(
      (summary) => (summary['profit_margin'] as double) > 0
    ).length;
    final atRiskProjects = _projectFinancialSummaries.where(
      (summary) => (summary['financial_status'] == 'warning' || summary['financial_status'] == 'over_budget')
    ).length;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            title: 'Projets Rentables',
            value: '$profitableProjects',
            icon: Icons.trending_up_rounded,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            title: 'Projets à Risque',
            value: '$atRiskProjects',
            icon: Icons.warning_rounded,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsTab(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentGold),
      );
    }
    
    return RefreshIndicator(
      color: AppTheme.accentGold,
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projectFinancialSummaries.length,
        itemBuilder: (context, index) {
          return _buildProjectCard(_projectFinancialSummaries[index], isDark, settings);
        },
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> summary, bool isDark, SettingsController settings) {
    final financialStatus = summary['financial_status'] as String;
    final statusColor = _getStatusColor(financialStatus);
    final statusIcon = _getStatusIcon(financialStatus);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        border: Border.all(
          color: statusColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary['project_name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          financialStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(summary['profit_margin'] as double).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Financial Details
          Row(
            children: [
              _buildDetailItem(
                isDark: isDark,
                label: 'Budget',
                value: '${(summary['estimation_budget'] as double).toStringAsFixed(2)} €',
              ),
              const SizedBox(width: 16),
              _buildDetailItem(
                isDark: isDark,
                label: 'Dépenses',
                value: '${(summary['total_expenses'] as double).toStringAsFixed(2)} €',
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              _buildDetailItem(
                isDark: isDark,
                label: 'Restant',
                value: '${(summary['remaining_budget'] as double).toStringAsFixed(2)} €',
              ),
              const SizedBox(width: 16),
              _buildDetailItem(
                isDark: isDark,
                label: 'Ratio',
                value: '${(summary['expense_ratio'] as double).toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required bool isDark,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      color: AppTheme.accentGold,
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Expense Summary
          if (_companySummary != null)
            _buildCompanySummaryCards(isDark, settings),
          
          // Recent Expenses List
          Expanded(
            child: FutureBuilder(
              future: ExpenseService.getAllProjectExpenses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentGold),
                  );
                }
                
                final expenses = snapshot.data ?? [];
                
                if (expenses.isEmpty) {
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
                          'Aucune dépense trouvée',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    return _buildExpenseCard(expenses[index], isDark, settings);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense, bool isDark, SettingsController settings) {
    final date = DateTime.parse(expense['date_depense']);
    final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense['categorie'] ?? 'Non catégorisé',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (expense['description'] != null && expense['description'].isNotEmpty)
                      Text(
                        expense['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                  '${(expense['montant'] as double).toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: expense['montant'] > 1000 ? Colors.red : AppTheme.accentGold,
                  ),
                ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (expense['projet_id'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Projet ID: ${expense['projet_id']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreditsTab(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      color: AppTheme.accentGold,
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Credit Summary
          _buildCreditSummaryCards(isDark, settings),
          
          // Credits List
          Expanded(
            child: FutureBuilder(
              future: CreditService.getAllCredits(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentGold),
                  );
                }
                
                final credits = snapshot.data ?? [];
                
                if (credits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 80,
                          color: AppTheme.accentGold.withOpacity(0.2),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Aucun crédit trouvé',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: credits.length,
                  itemBuilder: (context, index) {
                    return _buildCreditCard(credits[index], isDark, settings);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditSummaryCards(bool isDark, SettingsController settings) {
    return FutureBuilder(
      future: CreditService.getCreditSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentGold),
          );
        }
        
        final summary = snapshot.data;
        if (summary == null || !summary['success']) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            ),
            child: Center(
              child: Text(
                'Aucune donnée disponible',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          );
        }
        
        final data = summary['data'] as Map<String, dynamic>;
        
        return Column(
          children: [
            _buildMetricCard(
              isDark: isDark,
              title: 'Crédits Actifs',
              value: '${data['total_credits'] ?? 0}',
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.green,
              subtitle: 'Montant total',
            ),
            
            const SizedBox(height: 16),
            
            _buildMetricCard(
              isDark: isDark,
              title: 'Crédits Utilisés',
              value: '${data['used_credits'] ?? 0}',
              icon: Icons.account_balance_rounded,
              color: Colors.orange,
              subtitle: 'Montant utilisé',
            ),
            
            const SizedBox(height: 16),
            
            _buildMetricCard(
              isDark: isDark,
              title: 'Crédits Disponibles',
              value: '${data['available_credits'] ?? 0}',
              icon: Icons.savings_rounded,
              color: Colors.blue,
              subtitle: 'Montant restant',
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreditCard(Map<String, dynamic> credit, bool isDark, SettingsController settings) {
    final date = DateTime.parse(credit['date_credit']);
    final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credit['type'] ?? 'Crédit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (credit['description'] != null && credit['description'].isNotEmpty)
                      Text(
                        credit['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(credit['montant'] as double).toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGold,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (credit['client_id'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Client ID: ${credit['client_id']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (credit['projet_id'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Projet ID: ${credit['projet_id']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(SettingsController settings) {
    return AnimatedBuilder(
      animation: _refreshAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _refreshAnimation.value,
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
              heroTag: 'fab_refresh',
              onPressed: _refreshData,
              backgroundColor: Colors.transparent,
              elevation: 0,
              highlightElevation: 0,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(
                settings.translate('refresh'),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'caution':
        return Colors.yellow;
      case 'over_budget':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'caution':
        return Icons.info_rounded;
      case 'over_budget':
        return Icons.error_rounded;
      default:
        return Icons.help_rounded;
    }
  }
}
