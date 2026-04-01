import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import '../services/employee_service.dart';
import '../services/poste_service.dart';
import '../../auth/services/role_service.dart';
import 'package:fs_hub/shared/widgets/glass_avatar_picker.dart';
import 'package:fs_hub/shared/widgets/glass_text_field.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/glass_button.dart';
import '../../departments/services/department_service.dart';
import 'package:fs_hub/shared/models/department_model.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

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
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  DateTime? _dateNaissance;
  DateTime? _dateEmbauche;
  String _sexe = 'Homme';

  // Department
  Department? _selectedDepartment;
  List<Department> _availableDepartments = [];
  bool _isDeptsLoading = true;

  // Poste - filtered by department
  String? _selectedPoste;
  List<Map<String, dynamic>> _availablePostes = [];
  bool _isPostesLoading = false;

  // Role
  String _role = 'Employé';
  List<Map<String, dynamic>> _availableRoles = [];
  bool _isRolesLoading = true;

  // Poste→Role default mapping
  static const Map<String, String> _posteToRoleMap = {
    'Directeur': 'Admin',
    'Manager de projet': 'Manager',
    'Team Lead': 'Team Lead',
    'Développeur': 'Employé',
    'Designer': 'Employé',
    'Responsable RH': 'RH',
    'Comptable': 'Comptable',
    'Support technique': 'Employé',
  };

  String _typeContrat = 'CDI';
  String _statut = 'Actif';

  bool get _isEditMode => widget.employee != null;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadDepartments();
    _loadRoles();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isDeptsLoading = true);
    try {
      final depts = await DepartmentService.getAllDepartments();
      if (mounted) {
        setState(() {
          _availableDepartments = depts;
          _isDeptsLoading = false;
          if (widget.employee != null && _selectedDepartment == null) {
            try {
              _selectedDepartment = depts.firstWhere((d) => d.nom == widget.employee!.departement);
            } catch (e) {
              _selectedDepartment = depts.isNotEmpty ? depts.first : null;
            }
          } else if (depts.isNotEmpty && _selectedDepartment == null) {
            _selectedDepartment = depts.first;
          }
          
          if (_selectedDepartment != null && _selectedDepartment!.id != null) {
            _loadPostesByDepartment(_selectedDepartment!.id!);
          }
        });
      }
    } catch (e) {
      print('Error loading departments: $e');
      if (mounted) setState(() => _isDeptsLoading = false);
    }
  }

  Future<void> _loadPostesByDepartment(int departmentId) async {
    final oldPoste = _selectedPoste;
    setState(() {
      _isPostesLoading = true;
    });
    try {
      final postes = await PosteService.getPostesByDepartment(departmentId);
      if (mounted) {
        setState(() {
          _availablePostes = postes;
          _isPostesLoading = false;
          
          if (postes.isNotEmpty) {
            bool hasOldPoste = oldPoste != null && postes.any((p) => p['nom'] == oldPoste);
            if (hasOldPoste) {
              _selectedPoste = oldPoste;
            } else {
              _selectedPoste = postes.first['nom'] as String?;
              _autoSuggestRole(_selectedPoste);
            }
          } else {
            _selectedPoste = null;
          }
        });
      }
    } catch (e) {
      print('Error loading postes: $e');
      if (mounted) setState(() => _isPostesLoading = false);
    }
  }

  void _autoSuggestRole(String? posteName) {
    if (posteName == null) return;
    final suggestedRole = _posteToRoleMap[posteName];
    if (suggestedRole != null) {
      final roleExists = _availableRoles.any((r) => r['nom'] == suggestedRole);
      if (roleExists && mounted) {
        setState(() => _role = suggestedRole);
      }
    }
  }

  Future<void> _loadRoles() async {
    setState(() => _isRolesLoading = true);
    try {
      final roles = await RoleService.getAllRoles();
      if (mounted) {
        setState(() {
          _availableRoles = roles;
          _isRolesLoading = false;
          if (roles.isNotEmpty) {
            final roleExists = roles.any((r) => r['nom'] == _role);
            if (!roleExists) _role = roles.first['nom'] as String;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading roles: $e');
      if (mounted) setState(() => _isRolesLoading = false);
    }
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
    _usernameController = TextEditingController(text: emp?.username);
    _passwordController = TextEditingController();

    if (emp != null) {
      _dateNaissance = emp.dateNaissance;
      _dateEmbauche = emp.dateEmbauche;
      _sexe = emp.sexe;
      _selectedPoste = emp.poste;
      _typeContrat = emp.typeContrat;
      _statut = emp.statut;
      _role = emp.role ?? 'Employé';
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
        final bytes = await (_selectedImage as XFile).readAsBytes();
        photoBase64 = base64Encode(bytes);
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
        poste: _selectedPoste ?? '',
        departement: _selectedDepartment?.nom ?? '',
        dateEmbauche: _dateEmbauche!,
        typeContrat: _typeContrat,
        statut: _statut,
        username: _usernameController.text,
        role: _role,
        photo: photoBase64, // Base64 encoded image
        password: _passwordController.text, // Pass the password from the controller
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
          await showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withOpacity(0.5),
            builder: (ctx) => LuxuryStatusDialog(
              isSuccess: true,
              title: _isEditMode ? 'Protocol Updated' : 'Entity Created',
              message: result['message'] ?? 'Employee record has been synchronized with the central database.',
              onDismiss: () {},
            ),
          );
          if (mounted) Navigator.pop(context, true);
        } else {
          _showError(result['message'] ?? 'Data integrity breach detected.');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('System Interference: ${e.toString()}');
    }
  }

  void _showError(String message) {
    LuxuryStatusDialog.show(
      context,
      isSuccess: false,
      title: 'Execution Error',
      message: message,
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
            padding: const EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 40),
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
                    // Step 1: Department (loads first)
                    _isDeptsLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: LinearProgressIndicator(color: Color(0xFFD4AF37)),
                        )
                      : _buildDepartmentDropdown(isDark),
                    const SizedBox(height: 14),
                    // Step 2: Poste (filtered by selected department)
                    _isPostesLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: LinearProgressIndicator(color: Color(0xFFD4AF37)),
                        )
                      : _buildPosteDropdown(),
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
                    _isRolesLoading 
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: LinearProgressIndicator(color: Color(0xFFD4AF37)),
                        )
                      : _buildRoleDropdown(),

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
    // Clone and ensure current value is in the items to prevent crash
    final List<String> safeItems = List<String>.from(items);
    if (value.isNotEmpty && !safeItems.contains(value)) {
      safeItems.add(value);
    }
    
    // Ensure value is not null if we have items
    final String? selectedValue = value.isEmpty && safeItems.isNotEmpty ? safeItems.first : (value.isEmpty ? null : value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
                value: selectedValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
                items: safeItems.map((item) {
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

  Widget _buildDepartmentDropdown(bool isDark) {
    if (_availableDepartments.isEmpty) {
      return const Text('No departments found', style: TextStyle(color: Colors.red));
    }

    // Ensure selected dept is valid
    final validDept = _availableDepartments.any((d) => d.id == _selectedDepartment?.id)
        ? _selectedDepartment
        : _availableDepartments.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Département',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
              child: DropdownButtonFormField<Department>(
                value: validDept,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
                items: _availableDepartments.map((dept) {
                  return DropdownMenuItem<Department>(
                    value: dept,
                    child: Text(dept.nom, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (dept) {
                  if (dept != null && dept.id != null) {
                    setState(() => _selectedDepartment = dept);
                    _loadPostesByDepartment(dept.id!);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPosteDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posteNames = _availablePostes.map((p) => p['nom'] as String).toList();

    if (posteNames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          _selectedDepartment != null
              ? 'No postes found for ${_selectedDepartment!.nom}'
              : 'Select a department first',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
        ),
      );
    }

    // Ensure selection is valid
    String? selectedValue = _selectedPoste;
    if (selectedValue != null && !posteNames.contains(selectedValue)) {
      selectedValue = posteNames.first;
    }
    selectedValue ??= posteNames.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Poste / Fonction',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
                value: selectedValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
                items: posteNames.map((posteName) {
                  return DropdownMenuItem(
                    value: posteName,
                    child: Text(posteName, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPoste = value);
                    _autoSuggestRole(value);
                  }
                },
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleNames = _availableRoles.map((r) => r['nom'] as String).toList();
    
    // Ensure current value is in the list
    if (_role.isNotEmpty && !roleNames.contains(_role)) {
      roleNames.add(_role);
    }
    
    String? selectedValue = _role;
    if (selectedValue.isEmpty && roleNames.isNotEmpty) {
      selectedValue = roleNames.first;
      _role = selectedValue;
    } else if (selectedValue.isEmpty) {
      selectedValue = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Rôle',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
                value: selectedValue,
                isExpanded: true,
                itemHeight: null, // Allow custom height for multiline items
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
                items: roleNames.map((roleName) {
                  final role = _availableRoles.firstWhere((r) => r['nom'] == roleName, orElse: () => {'description': ''});
                  return DropdownMenuItem(
                    value: roleName,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(roleName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (role['description']?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              role['description'],
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
                selectedItemBuilder: (context) {
                  return roleNames.map((roleName) {
                    return Text(roleName, style: TextStyle(color: isDark ? Colors.white : Colors.black));
                  }).toList();
                },
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ),
        ),
      ],
    );
  }



  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
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
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

