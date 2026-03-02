import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/department_model.dart';
import '../services/department_service.dart';
import '../../../core/theme/app_theme.dart';

class AddEditDepartmentDialog extends StatefulWidget {
  final Department? department;
  const AddEditDepartmentDialog({super.key, this.department});

  @override
  State<AddEditDepartmentDialog> createState() => _AddEditDepartmentDialogState();
}

class _AddEditDepartmentDialogState extends State<AddEditDepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.department?.nom ?? '');
    _budgetController = TextEditingController(
      text: widget.department?.budgetAnnuel.toString() ?? '0.0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final dept = Department(
      id: widget.department?.id,
      nom: _nameController.text.trim(),
      budgetAnnuel: double.tryParse(_budgetController.text) ?? 0.0,
    );

    try {
      final result = widget.department == null
          ? await DepartmentService.createDepartment(dept)
          : await DepartmentService.updateDepartment(widget.department!.id!, dept);

      if (mounted) {
        if (result['success']) {
          Navigator.pop(context, true);
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      title: Text(widget.department == null ? 'Add Department' : 'Edit Department'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Department Name',
                labelStyle: TextStyle(color: AppTheme.accentGold.withOpacity(0.7)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accentGold),
                ),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Annual Budget (€)',
                labelStyle: TextStyle(color: AppTheme.accentGold.withOpacity(0.7)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accentGold),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Budget is required';
                if (double.tryParse(val) == null) return 'Must be a valid number';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentGold,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
