import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../shared/models/employee_model.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';

class EmployeeDetailPage extends StatelessWidget {
  final Employee employee;

  const EmployeeDetailPage({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: 'Employee Details',
      subtitle: employee.fullName,
      isPremium: true,
      actions: [
        LuxuryAppBarAction(
          icon: Icons.edit_outlined,
          onPressed: () {
            Navigator.pushNamed(
              context,
              AppRoutes.editEmployee,
              arguments: employee,
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
          padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
          child: Column(
            children: [
              _buildAvatarSection(isDark),
              const SizedBox(height: 32),
              _buildInfoSection(
                'Personal Information',
                [
                  _buildInfoRow('Matricule', employee.matricule, isDark),
                  _buildInfoRow('Full Name', employee.fullName, isDark),
                  _buildInfoRow('Date of Birth', _formatDate(employee.dateNaissance), isDark),
                  _buildInfoRow('Gender', employee.sexe, isDark),
                  _buildInfoRow('Email', employee.email, isDark),
                  _buildInfoRow('Phone', employee.telephone, isDark),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildInfoSection(
                'Address',
                [
                  _buildInfoRow('Address', employee.adresse, isDark),
                  _buildInfoRow('City', employee.ville, isDark),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildInfoSection(
                'Professional Information',
                [
                  _buildInfoRow('Position', employee.poste, isDark),
                  _buildInfoRow('Department', employee.departement, isDark),
                  _buildInfoRow('Hire Date', _formatDate(employee.dateEmbauche), isDark),
                  _buildInfoRow('Contract Type', employee.typeContrat, isDark),
                  _buildInfoRow('Status', employee.statut, isDark, isStatus: true),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildInfoSection(
                'Account Information',
                [
                  _buildInfoRow('Username', employee.username ?? 'N/A', isDark),
                  _buildInfoRow('Role', employee.role ?? 'N/A', isDark),
                  if (employee.permissions != null && employee.permissions!.isNotEmpty)
                    _buildPermissionsRow(employee.permissions!, isDark),
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
            child: employee.avatarUrl != null
                ? _buildImageWidget(employee.avatarUrl!, isDark)
                : _buildAvatarPlaceholder(isDark),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          employee.fullName,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          employee.poste,
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
          employee.prenom[0].toUpperCase() + employee.nom[0].toUpperCase(),
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
    final prefixLength = avatarUrl.length < 20 ? avatarUrl.length : 20;
    print('DEBUG DETAIL: avatarUrl starts with: ${avatarUrl.substring(0, prefixLength)}');
    print('DEBUG DETAIL: Contains base64,: ${avatarUrl.contains("base64,")}');
    print('DEBUG DETAIL: Starts with data:: ${avatarUrl.startsWith("data:")}');
    
    // Check if the URL is already a complete data URL
    if (avatarUrl.startsWith('data:')) {
      // This is already a complete data URL
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('DEBUG DETAIL: Image.network data URL error: $error');
          return _buildAvatarPlaceholder(isDark);
        },
      );
    } else if (avatarUrl.length > 100) { // Likely a base64 string if it's long
      // Assume it's a base64 string and convert to data URL
      try {
        // Validate that it's a proper base64 string
        base64Decode(avatarUrl);
        
        // Create a data URL with base64 image data
        String dataUrl = 'data:image/jpeg;base64,$avatarUrl';
        
        return Image.network(
          dataUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG DETAIL: Image.network base64 error: $error');
            return _buildAvatarPlaceholder(isDark);
          },
        );
      } catch (e) {
        print('DEBUG DETAIL: Error validating base64: $e');
        
        return _buildAvatarPlaceholder(isDark);
      }
    } else {
      // This is a regular URL
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildAvatarPlaceholder(isDark);
        },
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
