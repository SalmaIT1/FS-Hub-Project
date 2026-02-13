import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/employee_model.dart';
import '../services/employee_service.dart';
import '../../../shared/widgets/glass_avatar_picker.dart';
import '../../../shared/widgets/glass_text_field.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';

class AddEditEmployeePage extends StatefulWidget {
  final Employee? employee;

  const AddEditEmployeePage({super.key, this.employee});

  @override
  State<AddEditEmployeePage> createState() => _AddEditEmployeePageState();
}

class _AddEditEmployeePageState extends State<AddEditEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  dynamic _selectedImage;

  late TextEditingController _matriculeController;
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _emailController;
  late TextEditingController _telephoneController;
  late TextEditingController _adresseController;
  late TextEditingController _villeController;
  late TextEditingController _posteController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  DateTime? _dateNaissance;
  DateTime? _dateEmbauche;
  String _sexe = 'Homme';
  String _departement = 'IT';
  String _typeContrat = 'CDI';
  String _statut = 'Actif';
  String _role = 'Employé';
  List<String> _selectedPermissions = [];

  bool get _isEditMode => widget.employee != null;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final emp = widget.employee;
    _matriculeController = TextEditingController(text: emp?.matricule);
    _nomController = TextEditingController(text: emp?.nom);
    _prenomController = TextEditingController(text: emp?.prenom);
    _emailController = TextEditingController(text: emp?.email);
    _telephoneController = TextEditingController(text: emp?.telephone);
    _adresseController = TextEditingController(text: emp?.adresse);
    _villeController = TextEditingController(text: emp?.ville);
    _posteController = TextEditingController(text: emp?.poste);
    _usernameController = TextEditingController(text: emp?.username);
    _passwordController = TextEditingController();

    if (emp != null) {
      _dateNaissance = emp.dateNaissance;
      _dateEmbauche = emp.dateEmbauche;
      _sexe = emp.sexe;
      _departement = emp.departement;
      _typeContrat = emp.typeContrat;
      _statut = emp.statut;
      _role = emp.role ?? 'Employé';
      _selectedPermissions = emp.permissions ?? [];
    }
  }

  Future<void> _selectDate(BuildContext context, bool isBirthDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFFD4AF37),
              surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isBirthDate) {
          _dateNaissance = picked;
        } else {
          _dateEmbauche = picked;
        }
      });
    }
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateNaissance == null || _dateEmbauche == null) {
      _showError('Please select all required dates');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? photoBase64;
      if (_selectedImage != null) {
        if (kIsWeb) {
          // For web: convert XFile bytes to base64
          final bytes = await (_selectedImage as XFile).readAsBytes();
          photoBase64 = base64Encode(bytes);
        } else {
          // For mobile: read file and convert to base64
          // _selectedImage is already a file path string
          // This would need to be implemented with File I/O
          // For now, we'll handle web only
        }
      }

      final employeeData = Employee(
        id: widget.employee?.id,
        matricule: _matriculeController.text,
        nom: _nomController.text,
        prenom: _prenomController.text,
        dateNaissance: _dateNaissance!,
        sexe: _sexe,
        email: _emailController.text,
        telephone: _telephoneController.text,
        adresse: _adresseController.text,
        ville: _villeController.text,
        poste: _posteController.text,
        departement: _departement,
        dateEmbauche: _dateEmbauche!,
        typeContrat: _typeContrat,
        statut: _statut,
        username: _usernameController.text,
        role: _role,
        permissions: _selectedPermissions.isNotEmpty ? _selectedPermissions : null,
        photo: photoBase64, // Base64 encoded image
      );

      Map<String, dynamic> result;
      
      if (_isEditMode) {
        result = await EmployeeService.updateEmployee(
          widget.employee!.id!,
          employeeData,
        );
      } else {
        result = await EmployeeService.createEmployee(employeeData);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
          Navigator.pop(context, true);
        } else {
          _showError(result['message']);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: ${e.toString()}');
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: _isEditMode ? 'Edit Employee' : 'Add Employee',
      isPremium: true,
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
            child: Column(
              children: [
                GlassAvatarPicker(
                  initialImageUrl: widget.employee?.avatarUrl,
                  onImageSelected: (file) {
                    setState(() => _selectedImage = file);
                  },
                  size: 100,
                ),
                const SizedBox(height: 32),
                _buildSection(
                  'Personal Information',
                  [
                    GlassTextField(
                      label: 'Matricule',
                      controller: _matriculeController,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GlassTextField(
                            label: 'Nom',
                            controller: _nomController,
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassTextField(
                            label: 'Prénom',
                            controller: _prenomController,
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildDateField('Date de Naissance', _dateNaissance, true, isDark),
                    const SizedBox(height: 14),
                    _buildSegmentedControl(
                      'Sexe',
                      ['Homme', 'Femme'],
                      _sexe,
                      (v) => setState(() => _sexe = v),
                      isDark,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'Email',
                      controller: _emailController,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'Téléphone',
                      controller: _telephoneController,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ],
                  isDark,
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Address',
                  [
                    GlassTextField(
                      label: 'Adresse',
                      controller: _adresseController,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'Ville',
                      controller: _villeController,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ],
                  isDark,
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Professional Information',
                  [
                    GlassTextField(
                      label: 'Poste',
                      controller: _posteController,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      'Département',
                      _departement,
                      ['IT', 'Human Resources', 'Marketing', 'Finance', 'Sales'],
                      (v) => setState(() => _departement = v!),
                      isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildDateField('Date d\'Embauche', _dateEmbauche, false, isDark),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      'Type de Contrat',
                      _typeContrat,
                      ['CDI', 'CDD', 'Stage', 'Freelance'],
                      (v) => setState(() => _typeContrat = v!),
                      isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildSegmentedControl(
                      'Statut',
                      ['Actif', 'Suspendu', 'Démission'],
                      _statut,
                      (v) => setState(() => _statut = v),
                      isDark,
                    ),
                  ],
                  isDark,
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Account Information',
                  [
                    GlassTextField(
                      label: 'Username',
                      controller: _usernameController,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    if (!_isEditMode)
                      GlassTextField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: true,
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                    if (!_isEditMode) const SizedBox(height: 14),
                    _buildDropdown(
                      'Role',
                      _role,
                      ['Admin', 'RH', 'Employé'],
                      (v) => setState(() => _role = v!),
                      isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildPermissionsChips(isDark),
                  ],
                  isDark,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                        isPrimary: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GlassButton(
                        text: _isEditMode ? 'Update' : 'Create',
                        onPressed: _handleSave,
                        isLoading: _isLoading,
                        isPrimary: true,
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
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? date, bool isBirthDate, bool isDark) {
    return GestureDetector(
      onTap: () => _selectDate(context, isBirthDate),
      child: AbsorbPointer(
        child: GlassTextField(
          label: label,
          controller: TextEditingController(
            text: date != null ? '${date.day}/${date.month}/${date.year}' : '',
          ),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(
    String label,
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((option) {
            final isSelected = value == option;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                          : isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD4AF37)
                            : isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFD4AF37)
                            : isDark
                                ? Colors.white
                                : Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
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
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: value,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsChips(bool isDark) {
    final permissions = ['Read', 'Write', 'Delete', 'Manage Users', 'Reports'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permissions',
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: permissions.map((perm) {
            final isSelected = _selectedPermissions.contains(perm);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedPermissions.remove(perm);
                  } else {
                    _selectedPermissions.add(perm);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                      : isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFD4AF37)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  perm,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFD4AF37)
                        : isDark
                            ? Colors.white
                            : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _matriculeController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _posteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
