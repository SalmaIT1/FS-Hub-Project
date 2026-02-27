import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../models/client_model.dart';
import '../services/client_service.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/settings_controller.dart';

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
      6,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _fadeController,
          curve: Interval(index * 0.1, 1.0, curve: Curves.easeOutCubic),
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
    super.dispose();
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
        scoreCredit: 0, // Always start with 0, calculated automatically
      );

      final result = widget.client == null
          ? await ClientService.createClient(client)
          : await ClientService.updateClient(widget.client!.id!, client);

      if (result['success'] && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.client == null ? 'Client created successfully' : 'Client updated successfully'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'An error occurred'),
              backgroundColor: const Color(0xFFEF5350),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: const Color(0xFFEF5350),
          ),
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
      appBar: LuxuryAppBar(
        title: isEditing ? settings.translate('edit_client') : settings.translate('add_client'),
        subtitle: isEditing ? 'ID: ${widget.client!.id}' : settings.translate('new_client_subtitle'),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Client Type Selection
                        _buildAnimatedSection(0, _buildTypeSelector(isDark, settings)),
                        
                        const SizedBox(height: 20),
                        
                        // Basic Information
                        _buildAnimatedSection(1, _buildBasicInfoSection(isDark, settings)),
                        
                        const SizedBox(height: 20),
                        
                        // Contact Information
                        _buildAnimatedSection(2, _buildContactInfoSection(isDark, settings)),
                        
                        const SizedBox(height: 20),
                        
                        // Credit Score
                        _buildAnimatedSection(3, _buildCreditScoreSection(isDark, settings)),
                        
                        const SizedBox(height: 40),
                        
                        // Save Button
                        _buildAnimatedSection(4, _buildSaveButton(isDark, settings)),
                        
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAnimatedSection(int index, Widget child) {
    return AnimatedBuilder(
      animation: _staggeredAnimations[index],
      builder: (context, child) => Opacity(
        opacity: _staggeredAnimations[index].value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - _staggeredAnimations[index].value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark, SettingsController settings) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.translate('client_type'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = ClientType.particulier),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedType == ClientType.particulier
                          ? AppTheme.accentGold.withOpacity(0.2)
                          : isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedType == ClientType.particulier
                            ? AppTheme.accentGold
                            : isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: _selectedType == ClientType.particulier ? AppTheme.accentGold : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          settings.translate('particulier'),
                          style: TextStyle(
                            color: _selectedType == ClientType.particulier ? AppTheme.accentGold : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = ClientType.entreprise),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedType == ClientType.entreprise
                          ? AppTheme.accentGold.withOpacity(0.2)
                          : isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedType == ClientType.entreprise
                            ? AppTheme.accentGold
                            : isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_rounded,
                          color: _selectedType == ClientType.entreprise ? AppTheme.accentGold : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          settings.translate('entreprise'),
                          style: TextStyle(
                            color: _selectedType == ClientType.entreprise ? AppTheme.accentGold : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(bool isDark, SettingsController settings) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.translate('basic_info'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Nom
          TextFormField(
            controller: _nomController,
            decoration: _buildInputDecoration(settings.translate('nom'), Icons.person_rounded, isDark),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return settings.translate('required_field');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Prénom
          TextFormField(
            controller: _prenomController,
            decoration: _buildInputDecoration(settings.translate('prenom'), Icons.person_outline_rounded, isDark),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return settings.translate('required_field');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Raison Sociale (only for entreprise)
          if (_selectedType == ClientType.entreprise)
            TextFormField(
              controller: _raisonSocialeController,
              decoration: _buildInputDecoration(settings.translate('raison_sociale'), Icons.business_rounded, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildContactInfoSection(bool isDark, SettingsController settings) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.translate('contact_info'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Email
          TextFormField(
            controller: _emailController,
            decoration: _buildInputDecoration(settings.translate('email'), Icons.email_rounded, isDark),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty && !value.contains('@')) {
                return settings.translate('invalid_email');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Téléphone
          TextFormField(
            controller: _telephoneController,
            decoration: _buildInputDecoration(settings.translate('telephone'), Icons.phone_rounded, isDark),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditScoreSection(bool isDark, SettingsController settings) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.translate('credit_score'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Calculated automatically based on project payments',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _scoreCreditController,
            decoration: _buildInputDecoration('Credit Score', Icons.score_rounded, isDark).copyWith(
              suffixText: 'Auto-calculated',
              suffixStyle: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            keyboardType: TextInputType.number,
            readOnly: true,
            enabled: false,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.accentGold.withOpacity(0.7)),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.accentGold),
      ),
      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
    );
  }

  Widget _buildSaveButton(bool isDark, SettingsController settings) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [AppTheme.accentGold, Color(0xFF8B6914)]),
          boxShadow: [BoxShadow(color: AppTheme.accentGold.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: ElevatedButton(
          onPressed: _saveClient,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            widget.client == null ? settings.translate('create_client') : settings.translate('update_client'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
