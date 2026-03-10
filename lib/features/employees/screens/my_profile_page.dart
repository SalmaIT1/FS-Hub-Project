import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import 'package:fs_hub/shared/models/demand_model.dart';
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
  Employee? _employee;
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

        // Load employee data
        final employeeResult = await EmployeeService.getEmployeeById(user['id']!);
        if (employeeResult != null) {
          setState(() {
            _employee = employeeResult;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Identity Synchronization Failure',
          message: 'Unable to decrypt biological and professional profile data from the core mainframe.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return LuxuryScaffold(
      title: settings.translate('my_profile'),
      isPremium: true,
      actions: [
        if (_userRole != 'Admin')
          LuxuryAppBarAction(
            icon: Icons.add_circle_outline,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.createDemand);
            },
          ),
        LuxuryAppBarAction(
          icon: Icons.settings_outlined,
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.settings);
          },
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
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _employee == null
                  ? const Center(child: Text('Employee not found'))
                  : Column(
                      children: [
                        // Profile Header
                        Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _buildAvatarSection(isDark),
                              const SizedBox(height: 24),
                              Text(
                                _employee!.fullName,
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
                                  color: const Color(0xFFFFD700).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
                                ),
                                child: Text(
                                  _employee!.role ?? 'Employé',
                                  style: const TextStyle(
                                    color: Color(0xFFB8860B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Info Sections
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            children: [
                              _buildInfoSection(
                                settings.languageCode == 'fr' ? 'Informations Professionnelles' : 'Professional Info',
                                Icons.business_center_outlined,
                                [
                                  _buildInfoTile('Matricule', _employee!.matricule, Icons.badge_outlined, isDark),
                                  _buildInfoTile(settings.languageCode == 'fr' ? 'Poste' : 'Position', _employee!.poste, Icons.work_outline, isDark),
                                  _buildInfoTile('Département', _employee!.departement, Icons.account_tree_outlined, isDark),
                                  _buildInfoTile(settings.languageCode == 'fr' ? 'Date d\'embauche' : 'Hire Date', _formatDate(_employee!.dateEmbauche.toIso8601String()), Icons.calendar_today_outlined, isDark),
                                  _buildInfoTile('Contrat', _employee!.typeContrat, Icons.description_outlined, isDark),
                                ],
                                isDark,
                              ),
                              const SizedBox(height: 20),
                              _buildInfoSection(
                                settings.languageCode == 'fr' ? 'Coordonnées' : 'Contact Details',
                                Icons.contact_mail_outlined,
                                [
                                  _buildInfoTile('Email', _employee!.email, Icons.alternate_email, isDark),
                                  _buildInfoTile('Téléphone', _employee!.telephone, Icons.phone_android_outlined, isDark),
                                  _buildInfoTile('Adresse', _employee!.adresse, Icons.location_on_outlined, isDark),
                                  _buildInfoTile('Ville', _employee!.ville, Icons.location_city_outlined, isDark),
                                ],
                                isDark,
                              ),
                              const SizedBox(height: 20),
                              _buildInfoSection(
                                settings.languageCode == 'fr' ? 'Informations Personnelles' : 'Personal Details',
                                Icons.person_outline,
                                [
                                  _buildInfoTile(settings.languageCode == 'fr' ? 'Date de Naissance' : 'Date of Birth', _formatDate(_employee!.dateNaissance.toIso8601String()), Icons.cake_outlined, isDark),
                                  _buildInfoTile('Sexe', _employee!.sexe == 'M' ? 'Masculin' : 'Féminin', Icons.people_outline, isDark),
                                ],
                                isDark,
                              ),
                              const SizedBox(height: 160), // Space for FAB/Bottom Nav
                            ],
                          ),
                        ),
                      ],
                    ),
                ),
        ),
      );
  }

  Widget _buildAvatarSection(bool isDark) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: _employee!.avatarUrl != null
            ? _buildImageWidget(_employee!.avatarUrl!, isDark)
            : _buildAvatarPlaceholder(isDark),
      ),
    );
  }

  Widget _buildImageWidget(String avatarUrl, bool isDark) {
    // Check if the URL is already a complete data URL
    if (avatarUrl.startsWith('data:')) {
      return AuthenticatedImage(
        url: avatarUrl,
        fit: BoxFit.cover,
        errorWidget: _buildAvatarPlaceholder(isDark),
      );
    } else if (avatarUrl.length > 100 && !avatarUrl.startsWith('http')) { 
      // Likely a base64 string if it's long and not a URL
      return AuthenticatedImage(
        url: 'data:image/jpeg;base64,$avatarUrl',
        fit: BoxFit.cover,
        errorWidget: _buildAvatarPlaceholder(isDark),
      );
    } else {
      // This is a regular URL
      return AuthenticatedImage(
        url: avatarUrl,
        fit: BoxFit.cover,
        errorWidget: _buildAvatarPlaceholder(isDark),
      );
    }
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    return Container(
      color: isDark 
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.04),
      child: Center(
        child: Text(
          _employee!.prenom[0].toUpperCase() + _employee!.nom[0].toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
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
            Icon(icon, size: 18, color: const Color(0xFFFFD700)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            children: children,
          ),
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
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFB8860B)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


