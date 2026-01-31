import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';
import '../../widgets/luxury/luxury_app_bar.dart';
import '../../widgets/employee_card.dart';
import '../../routes/app_routes.dart';

class EmployeesListPage extends StatefulWidget {
  const EmployeesListPage({super.key});

  @override
  State<EmployeesListPage> createState() => _EmployeesListPageState();
}

class _EmployeesListPageState extends State<EmployeesListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedDepartment;
  String? _selectedStatus;
  
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    print('EmployeesListPage: _loadEmployees called');
    setState(() => _isLoading = true);
    try {
      final employees = await EmployeeService.getAllEmployees();
      print('EmployeesListPage: Received ${employees.length} employees');
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      print('EmployeesListPage: Error loading employees - $e');
      setState(() => _isLoading = false);
      _showError('Failed to load employees: ${e.toString()}');
    }
  }

  List<Employee> get _filteredEmployees {
    return _employees.where((emp) {
      final matchesSearch = emp.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.poste.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.departement.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesDepartment = _selectedDepartment == null || emp.departement == _selectedDepartment;
      final matchesStatus = _selectedStatus == null || emp.statut == _selectedStatus;
      
      return matchesSearch && matchesDepartment && matchesStatus;
    }).toList();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.black.withOpacity(0.8)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withOpacity(0.12)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Employees',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFilterDropdown(
                      'Department',
                      _selectedDepartment,
                      ['IT', 'Human Resources', 'Marketing', 'Finance', 'Sales'],
                      (value) => setState(() => _selectedDepartment = value),
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFilterDropdown(
                      'Status',
                      _selectedStatus,
                      ['Actif', 'Suspendu', 'Démission'],
                      (value) => setState(() => _selectedStatus = value),
                      isDark,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedDepartment = null;
                                _selectedStatus = null;
                              });
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark 
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark 
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 14,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showDeleteConfirmation(Employee employee) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.black.withOpacity(0.8)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withOpacity(0.12)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: const Color(0xFFEF5350),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Delete Employee',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Are you sure you want to delete ${employee.fullName}?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _deleteEmployee(employee);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF5350),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteEmployee(Employee employee) async {
    try {
      final result = await EmployeeService.deleteEmployee(employee.id!);
      
      if (result['success']) {
        _showSuccess(result['message']);
        _loadEmployees(); // Reload the list
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Failed to delete employee: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF5350),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: LuxuryScaffold(
        title: 'Employees',
        actions: [
          LuxuryAppBarAction(
            icon: Icons.filter_list_rounded,
            onPressed: _showFilterDialog,
          ),
        ],
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
            ? Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFFD4AF37),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadEmployees,
                color: const Color(0xFFD4AF37),
                child: Column(
                  children: [
                    // Search bar in the body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: LuxurySearchInline(
                        hintText: 'Search by name, position, or department...',
                        onQueryChanged: (query) {
                          setState(() => _searchQuery = query);
                        },
                      ),
                    ),
                    // Employee list
                    Expanded(
                      child: _filteredEmployees.isEmpty
                          ? Center(
                              child: Text(
                                'No employees found',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                              itemCount: _filteredEmployees.length,
                              itemBuilder: (context, index) {
                                final employee = _filteredEmployees[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: EmployeeCard(
                                    employee: employee,
                                    onTap: () async {
                                      final result = await Navigator.pushNamed(
                                        context,
                                        AppRoutes.employeeDetail,
                                        arguments: employee,
                                      );
                                      if (result == true) {
                                        _loadEmployees(); // Reload after editing
                                      }
                                    },
                                    onEdit: () async {
                                      final result = await Navigator.pushNamed(
                                        context,
                                        AppRoutes.editEmployee,
                                        arguments: employee,
                                      );
                                      if (result == true) {
                                        _loadEmployees(); // Reload after editing
                                      }
                                    },
                                    onDelete: () => _showDeleteConfirmation(employee),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
        ),
      ),
      floatingActionButton: _buildFAB(isDark),
    );
  }

  Widget _buildFAB(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFC99D2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, AppRoutes.addEmployee);
          if (result == true) {
            _loadEmployees(); // Reload the list after adding
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
