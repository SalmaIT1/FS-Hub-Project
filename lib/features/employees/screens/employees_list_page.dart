import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import '../services/employee_service.dart';
import '../../../widgets/employee_card.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import '../../auth/data/services/auth_service.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';
import 'package:fs_hub/core/security/protected_route.dart';
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
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Retrieval Segment Fault',
          message: 'Unable to decrypt the employee repository. Connection to the central mainframe may be compromised.',
        );
      }
    }
  }

  Future<void> _showDeleteDialog(Employee employee) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          settings.translate('delete_employee'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${settings.translate('confirm_delete_employee')} ${employee.fullName}?',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          settings.translate('delete_warning'),
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (employee.username != null && employee.username!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.person_remove_rounded, color: Colors.red[700], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Associated user account "@${employee.username}" will also be deleted.',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              settings.translate('cancel'),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(settings.translate('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteEmployee(employee);
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context, listen: false);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(settings.translate('deleting')),
          ],
        ),
      ),
    );

    try {
      final result = await EmployeeService.deleteEmployee(employee.id!);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      if (result['success']) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: true,
          title: settings.translate('employee_deleted'),
          message: result['message'],
        );
        _loadEmployees(); // Refresh the list
      } else {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: settings.translate('delete_failed'),
          message: result['message'],
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      LuxuryStatusDialog.show(
        context,
        isSuccess: false,
        title: settings.translate('delete_failed'),
        message: settings.translate('network_error'),
      );
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
    final settings = Provider.of<SettingsController>(context, listen: true);

    return ProtectedRoute(
      requiredPermissions: ['manage_employees', 'view_employees'],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LuxuryAppBar(
          title: settings.translate('team_members'),
          isPremium: true,
          showBackButton: false, // Inside main layout
        ),
        body: _buildBody(settings),
        floatingActionButton: _currentUserRole == 'Admin' ? _buildFAB(settings) : null,
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



  Widget _buildBody(SettingsController settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.8),
          radius: 1.2,
          colors: isDark 
              ? [const Color(0xFF0F0F0F), Colors.black]
              : [const Color(0xFFF8F8F8), const Color(0xFFECECEC)],
        ),
      ),
      child: _isLoading 
          ? const Center(child: ExcludeSemantics(child: CircularProgressIndicator(color: AppTheme.accentGold)))
          : Column(
              children: [
                _buildSummaryCard(isDark, settings),
                _buildSearchSection(isDark, settings),
                Expanded(
                  child: _filteredEmployees.isEmpty
                      ? _buildEmptyState(isDark, settings)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _filteredEmployees.length,
                          itemBuilder: (context, index) {
                            final employee = _filteredEmployees[index];
                            return AnimatedBuilder(
                              animation: _listController,
                              builder: (context, child) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: _listController,
                                    curve: Interval(
                                      (index / _filteredEmployees.length) * 0.5,
                                      0.5 + (index / _filteredEmployees.length) * 0.5,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  )),
                                  child: FadeTransition(
                                    opacity: _listController,
                                    child: EmployeeCard(
                                      employee: employee,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EmployeeDetailPage(employee: employee),
                                        ),
                                      ),
                                      onEdit: _currentUserRole == 'Admin' ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddEditEmployeePage(employee: employee),
                                        ),
                                      ).then((_) => _loadEmployees()) : null,
                                      onDelete: _currentUserRole == 'Admin' ? () => _showDeleteDialog(employee) : null,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}


