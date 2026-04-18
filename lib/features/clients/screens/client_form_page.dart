import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../models/client_model.dart';
import '../services/client_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class ClientFormPage extends StatefulWidget {
  final Client? client;

  const ClientFormPage({super.key, this.client});

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _raisonSocialeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _scoreCreditController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _adresseController = TextEditingController();
  String? _patenteFilePath;

  ClientType _selectedType = ClientType.particulier;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _staggeredAnimations = List.generate(
      9,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _fadeController,
          curve: Interval(index * 0.08, 1.0, curve: Curves.easeOutCubic),
        ),
      ),
    );

    _initializeData();
    _fadeController.forward();
  }

  void _initializeData() {
    if (widget.client != null) {
      final client = widget.client!;
      _nomController.text = client.nom;
      _prenomController.text = client.prenom;
      _raisonSocialeController.text = client.raisonSociale ?? '';
      _emailController.text = client.email ?? '';
      _telephoneController.text = client.telephone ?? '';
      _scoreCreditController.text = client.scoreCredit.toString();
      _matriculeController.text = client.matriculeFiscale ?? '';
      _adresseController.text = client.adresse ?? '';
      _patenteFilePath = client.patenteDocument;
      _selectedType = client.type;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _raisonSocialeController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _scoreCreditController.dispose();
    _matriculeController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _pickPatenteDocument() async {
    // In a real scenario: Use file_picker
    // final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png']);
    // if (result != null) setState(() { _patenteFilePath = result.files.single.path; });
    
    // Fallback: Simulons l'action pour le rendu UI.
    setState(() {
      _patenteFilePath = '/storage/emulated/0/Download/patente.pdf';
    });
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final client = Client(
        id: widget.client?.id,
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        raisonSociale: _raisonSocialeController.text.trim().isEmpty 
            ? null 
            : _raisonSocialeController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        telephone: _telephoneController.text.trim().isEmpty 
            ? null 
            : _telephoneController.text.trim(),
        type: _selectedType,
        scoreCredit: 0,
        matriculeFiscale: _matriculeController.text.trim().isEmpty ? null : _matriculeController.text.trim(),
        adresse: _adresseController.text.trim().isEmpty ? null : _adresseController.text.trim(),
        patenteDocument: _patenteFilePath,
      );

      final result = widget.client == null
          ? await ClientService.createClient(client)
          : await ClientService.updateClient(widget.client!.id!, client);

      if (result['success'] && mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: true,
          title: widget.client == null ? 'Client Onboarded' : 'Entity Synchronized',
          message: widget.client == null 
              ? 'External entity "${_nomController.text}" has been registered.' 
              : 'Client metadata updated successfully.',
        );
        Navigator.pop(context, true);
      } else {
        if (mounted) {
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Registry Fault',
            message: result['error'] ?? 'Central node rejected the update request.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Neural Link Failure',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context, listen: false);
    final isEditing = widget.client != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LuxuryAppBar(
        title: isEditing ? settings.translate('edit_client').toUpperCase() : settings.translate('add_client').toUpperCase(),
        subtitle: isEditing ? 'ENTITY SYNC: ${widget.client!.id}' : 'ESTABLISH NEW CONNECTION',
        showBackButton: true,
        onBackPress: () => Navigator.pop(context),
        isPremium: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF4F4F4),
        ),
        child: Stack(
          children: [
            // Subtle ambient glows
            if (isDark) ...[
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentGold.withOpacity(0.05),
                  ),
                  child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
                ),
              ),
            ],
            
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 120, 20, 100),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header badge
                            _buildAnimatedSection(0, Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_user_rounded, color: AppTheme.accentGold, size: 14),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEditing ? 'MODIFYING SECURE RECORD' : 'SECURE ONBOARDING',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        color: AppTheme.accentGold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                            
                            const SizedBox(height: 32),
                            
                            // Client Type Selection
                            _buildLabel('ENTITY CLASSIFICATION'),
                            _buildAnimatedSection(1, _buildTypeSelector(isDark, settings)),
                            
                            const SizedBox(height: 24),
                            
                            // Basic Information
                            _buildLabel('IDENTITY PARAMETERS'),
                            _staggeredInput(2, _nomController, settings.translate('nom'), Icons.person_rounded, isDark, (v) => v?.isEmpty ?? true ? settings.translate('required_field') : null),
                            const SizedBox(height: 12),
                            _staggeredInput(3, _prenomController, settings.translate('prenom'), Icons.person_outline_rounded, isDark, (v) => v?.isEmpty ?? true ? settings.translate('required_field') : null),
                            
                            if (_selectedType == ClientType.entreprise) ...[
                              const SizedBox(height: 12),
                              _staggeredInput(4, _raisonSocialeController, settings.translate('raison_sociale'), Icons.business_rounded, isDark, null),
                              const SizedBox(height: 12),
                              _staggeredInput(5, _matriculeController, 'Matricule Fiscale', Icons.receipt_long_rounded, isDark, (v) => v?.isEmpty ?? true ? 'Champ requis pour entreprise' : null),
                              const SizedBox(height: 12),
                              _staggeredInput(5, _adresseController, 'Adresse', Icons.location_on_rounded, isDark, (v) => v?.isEmpty ?? true ? 'Champ requis' : null),
                              const SizedBox(height: 12),
                              _buildAnimatedSection(5, InkWell(
                                onTap: _pickPatenteDocument,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.accentGold.withOpacity(0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.upload_file_rounded, color: AppTheme.accentGold.withOpacity(0.5), size: 18),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _patenteFilePath != null ? _patenteFilePath!.split('/').last : 'Uploader la patente',
                                          style: TextStyle(
                                            color: _patenteFilePath != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                            
                            const SizedBox(height: 24),
                            
                            // Contact Information
                            _buildLabel('COMMUNICATION CHANNELS'),
                            _staggeredInput(5, _emailController, settings.translate('email'), Icons.email_rounded, isDark, (v) {
                              if (v == null || v.isEmpty) return settings.translate('required_field');
                              if (!v.contains('@')) return settings.translate('invalid_email');
                              return null;
                            }, keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 12),
                            _staggeredInput(6, _telephoneController, settings.translate('telephone'), Icons.phone_rounded, isDark, (v) => v == null || v.isEmpty ? settings.translate('required_field') : null, keyboardType: TextInputType.phone),
                            
                            const SizedBox(height: 48),
                            
                            // Save Button
                            _buildAnimatedSection(7, _buildSaveButton(isDark, settings)),
                            
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _staggeredInput(int index, TextEditingController controller, String label, IconData icon, bool isDark, String? Function(String?)? validator, {TextInputType keyboardType = TextInputType.text}) {
    return _buildAnimatedSection(index, TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: _buildInputDecoration(label, icon, isDark),
    ));
  }

  Widget _buildAnimatedSection(int index, Widget child) {
    // Reusing the index-based animation logic
    final animIndex = index < _staggeredAnimations.length ? index : _staggeredAnimations.length - 1;
    return AnimatedBuilder(
      animation: _staggeredAnimations[animIndex],
      builder: (context, child) => Opacity(
        opacity: _staggeredAnimations[animIndex].value,
        child: Transform.translate(
          offset: Offset(0, 15 * (1 - _staggeredAnimations[animIndex].value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _buildTypeSelector(bool isDark, SettingsController settings) {
    return Row(
      children: [
        _buildTypeCard(ClientType.particulier, Icons.person_rounded, settings.translate('particulier'), isDark),
        const SizedBox(width: 12),
        _buildTypeCard(ClientType.entreprise, Icons.business_rounded, settings.translate('entreprise'), isDark),
      ],
    );
  }

  Widget _buildTypeCard(ClientType type, IconData icon, String label, bool isDark) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.accentGold.withOpacity(0.08)
                : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.accentGold : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected ? [
              BoxShadow(color: AppTheme.accentGold.withOpacity(0.1), blurRadius: 10)
            ] : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.accentGold : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.accentGold : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      prefixIcon: Icon(icon, color: AppTheme.accentGold.withOpacity(0.5), size: 18),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.05)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildSaveButton(bool isDark, SettingsController settings) {
    return GestureDetector(
      onTap: _saveClient,
      child: Container(
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
              color: AppTheme.accentGold.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            (widget.client == null ? settings.translate('create_client') : settings.translate('update_client')).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}


