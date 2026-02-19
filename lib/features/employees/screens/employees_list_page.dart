import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../shared/models/employee_model.dart';
import '../services/employee_service.dart';
import '../../../widgets/employee_card.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/services/auth_service.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/state/settings_controller.dart';
import 'employee_detail_page.dart';
import 'add_edit_employee_page.dart';

class EmployeesListPage extends StatefulWidget {
  const EmployeesListPage({super.key});

  @override
  State<EmployeesListPage> createState() => _EmployeesListPageState();
}

class _EmployeesListPageState extends State<EmployeesListPage> with SingleTickerProviderStateMixin {
  List<Employee> _employees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _currentUserRole;
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _currentUserRole = user['role'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await EmployeeService.getAllEmployees();
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoading = false;
        });
        _listController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employees: $e')),
        );
      }
    }
  }

  List<Employee> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _employees;
    return _employees.where((employee) {
      final query = _searchQuery.toLowerCase();
      return employee.fullName.toLowerCase().contains(query) ||
             employee.poste.toLowerCase().contains(query) ||
             employee.departement.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: LuxuryAppBar(
        title: settings.translate('team_directory'),
        subtitle: settings.translate('team_subtitle'),
        showBackButton: Navigator.canPop(context),
        onBackPress: () => Navigator.pop(context),
        isPremium: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: isDark 
                ? [const Color(0xFF0F0F0F), Colors.black]
                : [const Color(0xFFF8F8F8), const Color(0xFFECECEC)],
          ),
        ),
        child: RefreshIndicator(
          color: AppTheme.accentGold,
          onRefresh: _loadEmployees,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Statistics / Summary Section
              SliverToBoxAdapter(
                child: _buildSummaryCard(isDark, settings),
              ),

              // Search Section
              SliverToBoxAdapter(
                child: _buildSearchSection(isDark, settings),
              ),

              // Employees List
              _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
                    )
                  : _filteredEmployees.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState(isDark, settings))
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _listController,
                                    curve: Interval(
                                      (index / 10).clamp(0.0, 1.0),
                                      1.0,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                                );

                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: animation.value,
                                      child: Transform.translate(
                                        offset: Offset(0, 30 * (1 - animation.value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: EmployeeCard(
                                    employee: _filteredEmployees[index],
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EmployeeDetailPage(employee: _filteredEmployees[index]),
                                      ),
                                    ),
                                    onEdit: _currentUserRole == 'Admin' ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddEditEmployeePage(employee: _filteredEmployees[index]),
                                        ),
                                      ).then((_) => _loadEmployees());
                                    } : null,
                                  ),
                                );
                              },
                              childCount: _filteredEmployees.length,
                            ),
                          ),
                        ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentUserRole == 'Admin' ? _buildFAB(settings) : null,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(settings.translate('total_staff'), _employees.length.toString(), Icons.people_outline_rounded),
          Container(width: 1, height: 40, color: AppTheme.accentGold.withOpacity(0.1)),
          _buildStatItem(settings.translate('online'), _employees.where((e) => e.isOnline).length.toString(), Icons.bolt_rounded),
          Container(width: 1, height: 40, color: AppTheme.accentGold.withOpacity(0.1)),
          _buildStatItem(settings.translate('active'), _employees.where((e) => e.statut.toLowerCase() == 'actif').length.toString(), Icons.check_circle_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accentGold, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSearchSection(bool isDark, SettingsController settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
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
            hintText: settings.translate('staff_search_hint'),
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentGold, size: 20),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, SettingsController settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: AppTheme.accentGold.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isEmpty ? settings.translate('no_members_found') : settings.translate('no_results_ritual'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            settings.translate('refine_search'),
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(SettingsController settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 90), // Elevate FAB above the bottom nav bar
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
        heroTag: 'fab_employees',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddEditEmployeePage()),
        ).then((_) => _loadEmployees()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(settings.translate('add_member'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }
}
