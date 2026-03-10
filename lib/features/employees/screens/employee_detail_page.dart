import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/authenticated_image.dart';

import '../../auth/data/services/auth_service.dart';
import '../../../shared/widgets/luxury/luxury_status_dialog.dart';

class EmployeeDetailPage extends StatefulWidget {
  final Employee employee;

  const EmployeeDetailPage({super.key, required this.employee});

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  String? _currentUserRole;
  bool _isAdminResetting = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUserRole = user?['role'];
      });
    }
  }

  Future<void> _handleAdminResetPassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Protocol: Force Reset'),
        content: Text('Are you sure you want to generate a new password for ${widget.employee.fullName}? A secure transmission will be sent to ${widget.employee.email}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abort')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isAdminResetting = true);
      try {
        final result = await AuthService.adminResetUserPassword(widget.employee.id ?? '0');
        if (mounted) {
          setState(() => _isAdminResetting = false);
          if (result['success']) {
            LuxuryStatusDialog.show(
              context,
              isSuccess: true,
              title: 'Reset Completed',
              message: 'Security protocol executed. New credentials have been transmitted to the user.',
            );
          } else {
            LuxuryStatusDialog.show(
              context,
              isSuccess: false,
              title: 'Protocol Failed',
              message: result['message'] ?? 'Unable to complete force reset.',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isAdminResetting = false);
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'System Error',
            message: e.toString(),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: 'Employee Details',
      subtitle: widget.employee.fullName,
      isPremium: true,
      actions: [
        LuxuryAppBarAction(
          icon: Icons.edit_outlined,
          onPressed: () {
            Navigator.pushNamed(
              context,
              AppRoutes.editEmployee,
              arguments: widget.employee,
            );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 40),
          child: Column(
            children: [
              _buildAvatarSection(isDark),
              const SizedBox(height: 32),
              _buildInfoSection(
                'Personal Information',
                [
                  _buildInfoRow('Matricule', widget.employee.matricule, isDark),
                  _buildInfoRow('Full Name', widget.employee.fullName, isDark),
                  _buildInfoRow('Date of Birth', _formatDate(widget.employee.dateNaissance), isDark),
                  _buildInfoRow('Gender', widget.employee.sexe, isDark),
                  _buildInfoRow('Email', widget.employee.email, isDark),
                  _buildInfoRow('Phone', widget.employee.telephone, isDark),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildInfoSection(
                'Address',
                [
                  _buildInfoRow('Address', widget.employee.adresse, isDark),
                  _buildInfoRow('City', widget.employee.ville, isDark),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildInfoSection(
                'Professional Information',
                [
                  _buildInfoRow('Position', widget.employee.poste, isDark),
                  _buildInfoRow('Department', widget.employee.departement, isDark),
                  _buildInfoRow('Hire Date', _formatDate(widget.employee.dateEmbauche), isDark),
                  _buildInfoRow('Contract Type', widget.employee.typeContrat, isDark),
                  _buildInfoRow('Status', widget.employee.statut, isDark, isStatus: true),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildInfoSection(
                'Account Information',
                [
                  _buildInfoRow('Username', widget.employee.username ?? 'N/A', isDark),
                  _buildInfoRow('Role', widget.employee.role ?? 'N/A', isDark),
                  if (widget.employee.permissions != null && widget.employee.permissions!.isNotEmpty)
                    _buildPermissionsRow(widget.employee.permissions!, isDark),
                  
                  if (_currentUserRole == 'Admin') ...[
                    const Divider(height: 32, thickness: 0.5),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isAdminResetting ? null : _handleAdminResetPassword,
                        icon: _isAdminResetting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.lock_reset, color: Colors.red),
                        label: Text(_isAdminResetting ? 'Processing...' : 'Reset User Password', style: const TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
                isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(bool isDark) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
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
            child: widget.employee.avatarUrl != null
                ? _buildImageWidget(widget.employee.avatarUrl!, isDark)
                : _buildAvatarPlaceholder(isDark),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.employee.fullName,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.employee.poste,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    return Container(
      color: isDark 
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.04),
      child: Center(
        child: Text(
          widget.employee.prenom[0].toUpperCase() + widget.employee.nom[0].toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 40,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Column(
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
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: isStatus
                ? _buildStatusBadge(value, isDark)
                : Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'actif':
        statusColor = const Color(0xFF4CAF50);
        break;
      case 'suspendu':
        statusColor = const Color(0xFFFFA726);
        break;
      case 'démission':
        statusColor = const Color(0xFFEF5350);
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildPermissionsRow(List<String> permissions, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permissions',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: permissions.map((perm) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  perm,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String avatarUrl, bool isDark) {
    // Check if the URL is already a complete data URL
    if (avatarUrl.startsWith('data:')) {
      // This is already a complete data URL
      return AuthenticatedImage(
        url: avatarUrl,
        fit: BoxFit.cover,
        errorWidget: _buildAvatarPlaceholder(isDark),
      );
    } else if (avatarUrl.length > 100 && !avatarUrl.startsWith('http')) { 
      // Likely a base64 string if it's long and not a URL
      try {
        // Validate that it's a proper base64 string
        base64Decode(avatarUrl.replaceAll(RegExp(r'\s+'), ''));
        
        // Create a data URL with base64 image data
        String dataUrl = 'data:image/jpeg;base64,$avatarUrl';
        
        return AuthenticatedImage(
          url: dataUrl,
          fit: BoxFit.cover,
          errorWidget: _buildAvatarPlaceholder(isDark),
        );
      } catch (e) {
        return _buildAvatarPlaceholder(isDark);
      }
    } else {
      // This is a regular URL
      return AuthenticatedImage(
        url: avatarUrl,
        fit: BoxFit.cover,
        errorWidget: _buildAvatarPlaceholder(isDark),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

