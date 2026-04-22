import 'package:flutter/material.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import 'package:fs_hub/features/employees/services/employee_service.dart';
import 'package:fs_hub/features/hr/data/services/hr_service.dart';

class GrantBonusModal extends StatefulWidget {
  final bool isFr;
  const GrantBonusModal({super.key, required this.isFr});

  @override
  State<GrantBonusModal> createState() => _GrantBonusModalState();
}

class _GrantBonusModalState extends State<GrantBonusModal> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  
  final Set<String> _selectedIds = {};
  String _bonusType = 'performance';
  String _selectedDept = 'All';
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isSaving = false;

  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchCtrl.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onFilterChanged);
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredEmployees = _employees.where((e) {
        final matchesSearch = e.nom.toLowerCase().contains(query) || e.prenom.toLowerCase().contains(query);
        final matchesDept = _selectedDept == 'All' || e.departement == _selectedDept;
        return matchesSearch && matchesDept;
      }).toList();
    });
  }

  Future<void> _loadEmployees() async {
    try {
      final emps = await EmployeeService.getAllEmployees();
      if (mounted) {
        setState(() {
          _employees = emps;
          _filteredEmployees = emps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectAllVisible() {
    setState(() {
      final allSelected = _filteredEmployees.isNotEmpty && 
                         _filteredEmployees.every((e) => _selectedIds.contains(e.id));
      
      if (allSelected) {
        for (var e in _filteredEmployees) {
          if (e.id != null) _selectedIds.remove(e.id);
        }
      } else {
        for (var e in _filteredEmployees) {
          if (e.id != null) _selectedIds.add(e.id!);
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);
    
    // Using the new high-performance batch endpoint
    final success = await HrService.bulkGrantBonuses(
      _selectedIds.toList(),
      {
        'amount': amount,
        'reason': _reasonCtrl.text,
        'bonus_type': _bonusType,
        'granted_date': DateTime.now().toIso8601String(),
      }
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isFr ? 'Erreur lors de l\'attribution groupée' : 'Bulk grant operation failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bg = isDark ? const Color(0xFF151515) : const Color(0xFFF9F9F9);

    final depts = ['All', ..._employees.map((e) => e.departement).toSet()];
    final areAllVisibleSelected = _filteredEmployees.isNotEmpty && 
                                  _filteredEmployees.every((e) => _selectedIds.contains(e.id));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: _isLoading 
        ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: _gold)))
        : Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(
                widget.isFr ? 'Attribution de Primes Groupée' : 'Batch Bonus Granting',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 24),

              // Settings Header (Optimized for Batch)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _input(widget.isFr ? 'Montant (DT)' : 'Amount (DT)', controller: _amountCtrl, icon: Icons.payments_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _typeDropdown(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _input(widget.isFr ? 'Motif global' : 'Shared reason', controller: _reasonCtrl, icon: Icons.description_outlined),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Search & Dept Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: widget.isFr ? 'Rechercher...' : 'Search...',
                          prefixIcon: const Icon(Icons.search, color: _gold, size: 20),
                          filled: true,
                          fillColor: bg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
                        child: DropdownButton<String>(
                          value: _selectedDept,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) {
                            setState(() => _selectedDept = v ?? 'All');
                            _onFilterChanged();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Select All Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredEmployees.length} ${widget.isFr ? "employés trouvés" : "employees found"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      onPressed: _selectAllVisible,
                      icon: Icon(areAllVisibleSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: _gold),
                      label: Text(
                        areAllVisibleSelected ? (widget.isFr ? 'Désélectionner' : 'Deselect All') : (widget.isFr ? 'Tout sélectionner' : 'Select All'),
                        style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _filteredEmployees.length,
                  itemBuilder: (context, i) {
                    final emp = _filteredEmployees[i];
                    final isSelected = _selectedIds.contains(emp.id);
                    return _EmployeeSelectTile(
                      employee: emp,
                      isSelected: isSelected,
                      isDark: isDark,
                      onToggle: () => setState(() => isSelected ? _selectedIds.remove(emp.id) : _selectedIds.add(emp.id!)),
                    );
                  },
                ),
              ),

              // Bottom Action
              Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                decoration: BoxDecoration(
                  color: surface,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_selectedIds.length} ${widget.isFr ? "sélectionnés" : "selected"}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          Text(
                            widget.isFr ? 'Prêt à valider' : 'Ready to confirm',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: (_selectedIds.isEmpty || _isSaving) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.isFr ? 'Valider' : 'Confirm', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _input(String label, {required TextEditingController controller, required IconData icon}) {
    return TextField(
      controller: controller,
      keyboardType: label.contains('Montant') ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, size: 18, color: _gold),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _bonusType,
      decoration: InputDecoration(
        labelText: widget.isFr ? 'Type' : 'Type',
        labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      items: const [
        DropdownMenuItem(value: 'performance', child: Text('Perf.', style: TextStyle(fontSize: 13))),
        DropdownMenuItem(value: 'project_completion', child: Text('Projet', style: TextStyle(fontSize: 13))),
        DropdownMenuItem(value: 'holiday', child: Text('Fête', style: TextStyle(fontSize: 13))),
        DropdownMenuItem(value: 'referral', child: Text('Coopt.', style: TextStyle(fontSize: 13))),
        DropdownMenuItem(value: 'other', child: Text('Autre', style: TextStyle(fontSize: 13))),
      ],
      onChanged: (val) => setState(() => _bonusType = val ?? 'performance'),
    );
  }
}

class _EmployeeSelectTile extends StatelessWidget {
  final Employee employee;
  final bool isSelected, isDark;
  final VoidCallback onToggle;

  const _EmployeeSelectTile({
    required this.employee,
    required this.isSelected,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A24D);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? gold.withOpacity(0.08) : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? gold : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    employee.nom.isNotEmpty ? employee.nom[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${employee.prenom} ${employee.nom}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(employee.poste, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(),
                activeColor: gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
