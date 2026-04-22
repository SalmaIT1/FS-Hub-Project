import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import '../services/employee_service.dart';
import '../../auth/data/services/auth_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/routes/app_routes.dart';

import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/authenticated_image.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _userId;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user['id'] != null) {
        setState(() {
          _userId = user['id'];
          _userRole = user['role'];
        });

        if (_userRole != 'Client') {
          final employeeResult = await EmployeeService.getEmployeeById(user['id']!);
          if (employeeResult != null) {
            setState(() {
              _profileData = employeeResult.toJson();
              _profileData!['fullName'] = employeeResult.fullName;
            });
          }
        }
        
        if (_profileData == null) {
          final profile = await AuthService.getProfile();
          if (profile != null) {
            setState(() {
              _profileData = profile;
              if (profile['type'] == 'Entreprise' && profile['raisonSociale'] != null) {
                _profileData!['fullName'] = profile['raisonSociale'];
              } else {
                _profileData!['fullName'] = '${profile['prenom'] ?? ''} ${profile['nom'] ?? ''}'.trim();
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Identity Synchronization Failure',
          message: 'Unable to decrypt profile data.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '--';
    try {
      final date = dateValue is DateTime ? dateValue : DateTime.parse(dateValue.toString());
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateValue.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LuxuryAppBar(
        title: settings.translate('my_profile'),
        isPremium: true,
        showDefaultActions: true, // Restore notifications and user menu
        actions: [
          if (_userRole != 'Admin' && _userRole != 'Client')
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.createDemand),
            ),
          if (_userRole == 'Client')
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              tooltip: settings.languageCode == 'fr' ? 'Retour au Portail' : 'Back to Portal',
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
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
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
              : _profileData == null
                  ? const Center(child: Text('Profile not found'))
                  : _buildProfileContent(settings, isDark),
        ),
      ),
    );
  }

  Widget _buildProfileContent(SettingsController settings, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildAvatarSection(isDark),
              const SizedBox(height: 24),
              Text(
                _profileData!['fullName'] ?? 'User',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.2)),
                ),
                child: Text(
                  _userRole ?? 'User',
                  style: const TextStyle(
                    color: Color(0xFFC9A24D),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              if (_userRole != 'Client') ...[
                _buildInfoSection(
                  settings.languageCode == 'fr' ? 'Informations Professionnelles' : 'Professional Info',
                  Icons.business_center_outlined,
                  [
                    _buildInfoTile('Matricule', _profileData!['matricule']?.toString() ?? '--', Icons.badge_outlined, isDark),
                    _buildInfoTile(settings.languageCode == 'fr' ? 'Poste' : 'Position', _profileData!['poste'] ?? '--', Icons.work_outline, isDark),
                    _buildInfoTile('Département', _profileData!['departement'] ?? '--', Icons.account_tree_outlined, isDark),
                    if (_profileData!['dateEmbauche'] != null)
                      _buildInfoTile(settings.languageCode == 'fr' ? 'Date d\'embauche' : 'Hire Date', _formatDate(_profileData!['dateEmbauche']), Icons.calendar_today_outlined, isDark),
                  ],
                  isDark,
                ),
              ] else ...[
                // Client Specific Brand Info
                _buildInfoSection(
                  settings.languageCode == 'fr' ? 'Informations Client' : 'Client Details',
                  Icons.business_outlined,
                  [
                    if (_profileData!['type'] == 'Entreprise') ...[
                      if (_profileData!['raisonSociale'] != null)
                        _buildInfoTile(settings.languageCode == 'fr' ? 'Raison Sociale' : 'Company Name', _profileData!['raisonSociale']!, Icons.apartment, isDark),
                      _buildInfoTile(settings.languageCode == 'fr' ? 'Contact' : 'Contact Person', '${_profileData!['prenom'] ?? ''} ${_profileData!['nom'] ?? ''}'.trim(), Icons.person_outline, isDark),
                    ] else ...[
                      _buildInfoTile(settings.languageCode == 'fr' ? 'Nom complet' : 'Full Name', '${_profileData!['prenom'] ?? ''} ${_profileData!['nom'] ?? ''}'.trim(), Icons.person_outline, isDark),
                    ],
                    
                    if (_profileData!['matriculeFiscale'] != null)
                      _buildInfoTile(settings.languageCode == 'fr' ? 'Matricule Fiscale' : 'Tax ID', _profileData!['matriculeFiscale']!, Icons.gavel, isDark),
                    
                    _buildInfoTile('Type', _profileData!['type'] ?? 'Particulier', Icons.category_outlined, isDark),
                    
                    if (_profileData!['scoreCredit'] != null)
                      _buildInfoTile('Score Crédit', _profileData!['scoreCredit'].toString(), Icons.speed, isDark),
                  ],
                  isDark,
                ),
              ],
              const SizedBox(height: 20),
              _buildInfoSection(
                settings.languageCode == 'fr' ? 'Coordonnées' : 'Contact Details',
                Icons.contact_mail_outlined,
                [
                  _buildInfoTile('Email', _profileData!['email'] ?? '--', Icons.alternate_email, isDark),
                  if (_profileData!['telephone'] != null)
                    _buildInfoTile('Téléphone', _profileData!['telephone']!, Icons.phone_android_outlined, isDark),
                  if (_profileData!['adresse'] != null)
                    _buildInfoTile('Adresse', _profileData!['adresse']!, Icons.location_on_outlined, isDark),
                ],
                isDark,
              ),
              if (_profileData!['dateNaissance'] != null) ...[
                const SizedBox(height: 20),
                _buildInfoSection(
                  settings.languageCode == 'fr' ? 'Informations Personnelles' : 'Personal Details',
                  Icons.person_outline,
                  [
                    _buildInfoTile(settings.languageCode == 'fr' ? 'Date de Naissance' : 'Date of Birth', _formatDate(_profileData!['dateNaissance']), Icons.cake_outlined, isDark),
                    if (_profileData!['sexe'] != null)
                      _buildInfoTile('Sexe', _profileData!['sexe'] == 'M' ? 'Masculin' : 'Féminin', Icons.people_outline, isDark),
                  ],
                  isDark,
                ),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection(bool isDark) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: _profileData!['avatarUrl'] != null
            ? AuthenticatedImage(
                url: _profileData!['avatarUrl']!,
                fit: BoxFit.cover,
                errorWidget: _buildAvatarPlaceholder(isDark),
              )
            : _buildAvatarPlaceholder(isDark),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    final prenom = _profileData!['prenom']?.toString() ?? 'U';
    final nom = _profileData!['nom']?.toString() ?? '';
    final initials = (prenom.isNotEmpty ? prenom[0] : '') + (nom.isNotEmpty ? nom[0] : '');
    
    return Container(
      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 30, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFC9A24D)),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFC9A24D).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: const Color(0xFFC9A24D)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
