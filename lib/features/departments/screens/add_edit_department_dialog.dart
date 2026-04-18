import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fs_hub/shared/models/department_model.dart';
import '../services/department_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

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
          LuxuryStatusDialog.show(
            context,
            isSuccess: true,
            title: widget.department == null ? 'Division Established' : 'Division Updated',
            message: 'Department "${_nameController.text}" registry has been successfully updated.',
          );
        } else {
          setState(() => _isSaving = false);
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Registry Fault',
            message: result['message'] ?? 'Core validator rejected the department parameters.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Neural Link Failure',
          message: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151515).withOpacity(0.95) : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_tree_rounded, color: AppTheme.accentGold, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          widget.department == null ? 'NEW DIVISION' : 'REFINE DIVISION',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: AppTheme.accentGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    _buildLabel('DIVISION IDENTIFIER'),
                    _buildTextField(_nameController, 'Corporate Name', isDark, Icons.business_rounded, (val) => val == null || val.isEmpty ? 'Name is required' : null),
                    
                    const SizedBox(height: 20),
                    
                    _buildLabel('ANNUAL RESOURCE ALLOCATION (DT)'),
                    _buildTextField(_budgetController, '0.00', isDark, Icons.account_balance_wallet_rounded, (val) {
                      if (val == null || val.isEmpty) return 'Budget is required';
                      if (double.tryParse(val) == null) return 'Must be a valid number';
                      return null;
                    }, keyboardType: TextInputType.number),
                    
                    const SizedBox(height: 36),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              'ABORT',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isSaving ? null : _save,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.accentGold, Color(0xFF8B6914)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentGold.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isSaving 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(
                                      widget.department == null ? 'ESTABLISH' : 'SYNCHRONIZE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isDark, IconData icon, String? Function(String?)? validator, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
        prefixIcon: Icon(icon, color: AppTheme.accentGold.withOpacity(0.5), size: 18),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

