import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/department_model.dart';
import '../services/department_service.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/settings_controller.dart';
import '../../../shared/widgets/luxury/luxury_status_dialog.dart';
import 'add_edit_department_dialog.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> with SingleTickerProviderStateMixin {
  List<Department> _departments = [];
  bool _isLoading = true;
  String? _currentUserRole;
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadDepartments();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoading = true);
    try {
      final departments = await DepartmentService.getAllDepartments();
      if (mounted) {
        setState(() {
          _departments = departments;
          _isLoading = false;
        });
        _listController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading departments: $e')),
        );
      }
    }
  }

  void _showAddEditDialog([Department? department]) {
    showDialog(
      context: context,
      builder: (context) => AddEditDepartmentDialog(department: department),
    ).then((updated) {
      if (updated == true) {
        _loadDepartments();
      }
    });
  }

  Future<void> _deleteDepartment(Department dept) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the department "${dept.nom}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && dept.id != null) {
      final result = await DepartmentService.deleteDepartment(dept.id!);
      if (mounted) {
        if (result['success']) {
          _loadDepartments();
          LuxuryStatusDialog.show(
            context,
            isSuccess: true,
            title: 'Division Decommissioned',
            message: 'Department "${dept.nom}" has been successfully removed from the organizational map.',
          );
        } else {
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Decommissioning Fault',
            message: result['message'] ?? 'Structure integrity constraints prevented the removal.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context, listen: true);

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Departments',
        subtitle: 'Manage organizational units',
        showBackButton: true,
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
          onRefresh: _loadDepartments,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
              : _departments.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: _departments.length,
                      itemBuilder: (context, index) {
                        final dept = _departments[index];
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
                          child: _buildDepartmentCard(dept, isDark),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildDepartmentCard(Department dept, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentGold.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          dept.nom,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, 
                     size: 14, color: AppTheme.accentGold.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(
                  'Budget: ${dept.budgetAnnuel.toStringAsFixed(2)} €',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.accentGold),
              onPressed: () => _showAddEditDialog(dept),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
              onPressed: () => _deleteDepartment(dept),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_outlined, 
               size: 80, color: AppTheme.accentGold.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            'No departments found',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.white70 : Colors.black54
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first department to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Department',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
