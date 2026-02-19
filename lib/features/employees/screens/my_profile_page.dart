import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/employee_model.dart';
import '../../../shared/models/demand_model.dart';
import '../services/employee_service.dart';
import '../../auth/data/services/auth_service.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/routes/app_routes.dart';

import 'package:provider/provider.dart';
import '../../../core/state/settings_controller.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  Employee? _employee;
  List<Demand> _demands = [];
  bool _isLoading = true;
  bool _demandsLoading = true;
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

        // Load demands
        await _loadDemands();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
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

  Future<void> _loadDemands() async {
    if (_userId == null) return;

    setState(() {
      _demandsLoading = true;
    });

    try {
      final result = await EmployeeService.getAllDemands();
      if (result['success'] == true && result['data'] != null && mounted) {
        final List<dynamic> demandData = result['data'];
        final demands = demandData.map((item) => Demand.fromJson(item)).toList();

        // Filter demands for this user only
        setState(() {
          _demands = demands.where((demand) => demand.requesterId == _userId).toList();
          _demandsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _demandsLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading demands: $e')),
        );
      }
    }
  }

  String _getTypeDisplayName(String type, SettingsController settings) {
    if (settings.languageCode == 'fr') {
      switch (type) {
        case 'password_reset':
          return 'Réinitialisation de mot de passe';
        case 'hardware':
          return 'Matériel';
        case 'administrative':
          return 'Administratif';
        case 'custom':
          return 'Personnalisé';
        default:
          return type;
      }
    }
    switch (type) {
      case 'password_reset':
        return 'Password Reset';
      case 'hardware':
        return 'Hardware';
      case 'administrative':
        return 'Administrative';
      case 'custom':
        return 'Custom';
      default:
        return type;
    }
  }

  String _getStatusDisplayName(String status, SettingsController settings) {
    if (settings.languageCode == 'fr') {
      switch (status) {
        case 'pending':
          return 'En attente';
        case 'in_progress':
          return 'En cours';
        case 'resolved':
          return 'Résolu';
        case 'rejected':
          return 'Rejeté';
        default:
          return status;
      }
    }
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'password_reset':
        return Icons.lock_reset;
      case 'hardware':
        return Icons.computer;
      case 'administrative':
        return Icons.receipt;
      case 'custom':
        return Icons.edit_note;
      default:
        return Icons.help_outline;
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
      showBackButton: Navigator.canPop(context),
      onBackPress: () => Navigator.pop(context),
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
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildAvatarSection(isDark),
                              const SizedBox(height: 24),
                              Text(
                                _employee!.fullName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _employee!.poste,
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Demands Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      settings.translate('my_demands'),
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_userRole != 'Admin')
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(context, AppRoutes.createDemand);
                                        },
                                        child: Text(
                                          settings.translate('new_demand'),
                                          style: TextStyle(
                                            color: const Color(0xFFFFD700),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              
                              _demandsLoading
                                  ? const Expanded(
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  : _demands.isEmpty
                                      ? Expanded(
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.assignment_outlined,
                                                  size: 64,
                                                  color: isDark 
                                                      ? Colors.white.withOpacity(0.6) 
                                                      : Colors.black.withOpacity(0.4),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  settings.languageCode == 'fr' ? 'Aucune demande pour le moment' : 'No demands yet',
                                                  style: TextStyle(
                                                    color: isDark 
                                                        ? Colors.white.withOpacity(0.6) 
                                                        : Colors.black.withOpacity(0.4),
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (_userRole != 'Admin') ...[
                                                  const SizedBox(height: 16),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pushNamed(context, AppRoutes.createDemand);
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFFFD700),
                                                      foregroundColor: Colors.black,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                    ),
                                                    child: Text(settings.translate('new_demand')),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        )
                                      : Expanded(
                                          child: RefreshIndicator(
                                            onRefresh: _loadDemands,
                                            child: ListView.separated(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              itemCount: _demands.length,
                                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                                              itemBuilder: (context, index) {
                                                final demand = _demands[index];
                                                return _buildDemandCard(demand, isDark, settings);
                                              },
                                            ),
                                          ),
                                        ),
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
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildAvatarPlaceholder(isDark);
        },
      );
    } else if (avatarUrl.length > 100) { // Likely a base64 string if it's long
      return Image.network(
        'data:image/jpeg;base64,$avatarUrl',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildAvatarPlaceholder(isDark);
        },
      );
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

  Widget _buildDemandCard(Demand demand, bool isDark, SettingsController settings) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.black.withOpacity(0.03),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Navigate to demand detail if needed
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Type icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getStatusColor(demand.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconForType(demand.type),
                      size: 18,
                      color: _getStatusColor(demand.status),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          _getTypeDisplayName(demand.type, settings),
                          style: TextStyle(
                            color: isDark 
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Description preview
                        Text(
                          demand.description.length > 80
                              ? '${demand.description.substring(0, 80)}...'
                              : demand.description,
                          style: TextStyle(
                            color: isDark 
                                ? Colors.white60
                                : Colors.black45,
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Status and date
                        Row(
                           children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(demand.status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getStatusColor(demand.status).withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                _getStatusDisplayName(demand.status, settings),
                                style: TextStyle(
                                  color: _getStatusColor(demand.status),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            Text(
                              _formatDate(demand.createdAt),
                              style: TextStyle(
                                color: isDark 
                                    ? Colors.white54
                                    : Colors.black45,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}