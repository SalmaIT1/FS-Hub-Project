import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/finance/services/expense_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/core/security/protected_route.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class AddProjectExpensePage extends StatefulWidget {
  final Map<String, dynamic>? expense;

  const AddProjectExpensePage({super.key, this.expense});

  @override
  State<AddProjectExpensePage> createState() => _AddProjectExpensePageState();
}

class _AddProjectExpensePageState extends State<AddProjectExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _categorieController = TextEditingController();
  final _montantController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _projectIdController = TextEditingController();
  
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  String? _selectedCategoryId;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.expense != null;
    _selectedDate = DateTime.now();
    _loadCategories();
    
    if (_isEditing) {
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _categorieController.dispose();
    _montantController.dispose();
    _descriptionController.dispose();
    _projectIdController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    if (widget.expense != null) {
      final expense = widget.expense!;
      _categorieController.text = expense['categorie'] ?? '';
      _montantController.text = expense['montant']?.toString() ?? '';
      _descriptionController.text = expense['description'] ?? '';
      _projectIdController.text = expense['projet_id']?.toString() ?? '';
      _selectedCategoryId = expense['category_id']?.toString();
      _selectedDate = DateTime.tryParse(expense['date_depense']) ?? DateTime.now();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ExpenseService.getExpenseCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Erreur',
          message: 'Impossible de charger les catégories',
        );
      }
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final expenseData = {
        'categorie': _categorieController.text,
        'montant': double.parse(_montantController.text),
        'date_depense': _selectedDate!.toIso8601String().split('T')[0],
        'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
        'projet_id': _projectIdController.text.isEmpty ? null : int.tryParse(_projectIdController.text),
        'category_id': _selectedCategoryId != null ? int.tryParse(_selectedCategoryId!) : null,
      };

      Map<String, dynamic> result;
      if (_isEditing) {
        result = await ExpenseService.updateProjectExpense(
          widget.expense!['id'],
          expenseData,
        );
      } else {
        result = await ExpenseService.createProjectExpense(expenseData);
      }

      if (mounted) {
        if (result['success']) {
          LuxuryStatusDialog.show(
            context,
            isSuccess: true,
            title: _isEditing ? 'Dépense Modifiée' : 'Dépense Ajoutée',
            message: result['message'],
          );
          Navigator.pop(context, true);
        } else {
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Erreur',
            message: result['message'],
          );
        }
      }
    } catch (e) {
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Erreur',
          message: 'Une erreur est survenue: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context, listen: true);

    return ProtectedRoute(
      requiredPermissions: ['manage_project_expenses'],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: LuxuryAppBar(
          title: _isEditing ? 'Modifier la Dépense' : 'Ajouter une Dépense',
        ),
        body: _buildBody(settings),
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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),
              
              // Title Section
              _buildTitleSection(isDark, settings),
              
              const SizedBox(height: 32),
              
              // Form Fields
              _buildFormFields(isDark, settings),
              
              const SizedBox(height: 40),
              
              // Save Button
              _buildSaveButton(settings),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isDark, SettingsController settings) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Icon(
            _isEditing ? Icons.edit_rounded : Icons.receipt_long_rounded,
            size: 48,
            color: AppTheme.accentGold,
          ),
          const SizedBox(height: 16),
          Text(
            _isEditing ? 'Modifier la Dépense' : 'Ajouter une Dépense',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isEditing 
                ? 'Modifiez les informations de la dépense'
                : 'Remplissez les informations pour ajouter une nouvelle dépense',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(bool isDark, SettingsController settings) {
    return Column(
      children: [
        // Category Dropdown
        _isLoadingCategories
            ? Container(
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentGold),
                ),
              )
            : _buildCategoryDropdown(isDark, settings),
        
        const SizedBox(height: 20),
        
        // Amount Field
        _buildTextField(
          controller: _montantController,
          label: 'Montant (DT)',
          hint: '0.00',
          icon: Icons.payments_rounded,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer un montant';
            }
            if (double.tryParse(value) == null) {
              return 'Veuillez entrer un montant valide';
            }
            return null;
          },
          isDark: isDark,
        ),
        
        const SizedBox(height: 20),
        
        // Date Picker
        _buildDateField(isDark, settings),
        
        const SizedBox(height: 20),
        
        // Project ID Field (Optional)
        _buildTextField(
          controller: _projectIdController,
          label: 'ID du Projet (optionnel)',
          hint: '123',
          icon: Icons.work_outline_rounded,
          keyboardType: TextInputType.number,
          validator: null,
          isDark: isDark,
        ),
        
        const SizedBox(height: 20),
        
        // Description Field (Optional)
        _buildTextField(
          controller: _descriptionController,
          label: 'Description (optionnelle)',
          hint: 'Ajoutez une description...',
          icon: Icons.description_outlined,
          keyboardType: TextInputType.multiline,
          maxLines: 3,
          validator: null,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(bool isDark, SettingsController settings) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCategoryId,
        decoration: InputDecoration(
          labelText: 'Catégorie',
          hintText: 'Sélectionnez une catégorie',
          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          prefixIcon: Icon(Icons.category_rounded, color: AppTheme.accentGold),
        ),
        dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        items: _categories.map((category) {
          return DropdownMenuItem<String>(
            value: category['id'].toString(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category['nom'],
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (category['description'] != null && category['description'].isNotEmpty)
                  Text(
                    category['description'],
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedCategoryId = value);
          // Update categorie controller when category changes
          final selectedCategory = _categories.firstWhere(
            (cat) => cat['id'].toString() == value,
            orElse: () => {'nom': ''},
          );
          _categorieController.text = selectedCategory['nom'] ?? '';
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner une catégorie';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField(bool isDark, SettingsController settings) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.accentGold,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date de la dépense',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Sélectionnez une date',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate != null
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white38 : Colors.black38),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
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
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required String? Function(String?)? validator,
    required bool isDark,
    int? maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        validator: validator,
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          prefixIcon: Icon(icon, color: AppTheme.accentGold, size: 24),
        ),
      ),
    );
  }

  Widget _buildSaveButton(SettingsController settings) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveExpense,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Enregistrement...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEditing ? Icons.save_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Modifier la Dépense' : 'Ajouter la Dépense',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
