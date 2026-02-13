import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../shared/models/employee_model.dart';
import '../services/employee_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../widgets/employee_card.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/services/auth_service.dart';
import '../../../core/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'employee_detail_page.dart';
import 'add_edit_employee_page.dart';

class EmployeesListPage extends StatefulWidget {
  const EmployeesListPage({super.key});

  @override
  State<EmployeesListPage> createState() => _EmployeesListPageState();
}

class _EmployeesListPageState extends State<EmployeesListPage> {
  List<Employee> _employees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
    setState(() {
      _isLoading = true;
    });

    try {
      final employees = await EmployeeService.getAllEmployees();
      
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employees: $e')),
        );
      }
    }
  }

  List<Employee> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _employees;
    
    return _employees.where((employee) {
      final name = employee.fullName.toLowerCase();
      final email = employee.email.toLowerCase();
      final role = employee.role?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query) || role.contains(query);
    }).toList();
  }

  void _showDeleteConfirmation(Employee employee) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Employee'),
          content: Text('Are you sure you want to delete ${employee.fullName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final result = await EmployeeService.deleteEmployee(employee.id!);
                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Employee deleted successfully'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                  _loadEmployees();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']),
                      backgroundColor: Color(0xFFEF5350),
                    ),
                  );
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Employees',
        subtitle: 'Manage and organize your team',
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
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadEmployees,
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.05) 
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search employees...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            
              // Employees list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredEmployees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: isDark ? Colors.white38 : Colors.black26,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty ? 'No employees found' : 'No matching employees',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try a different search term',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white54 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredEmployees.length,
                            itemBuilder: (context, index) {
                              final employee = _filteredEmployees[index];
                              return EmployeeCard(
                                employee: employee,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EmployeeDetailPage(employee: employee),
                                    ),
                                  );
                                },
                                onEdit: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddEditEmployeePage(employee: employee),
                                    ),
                                  ).then((_) => _loadEmployees());
                                },
                                onDelete: () {
                                  _showDeleteConfirmation(employee);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}