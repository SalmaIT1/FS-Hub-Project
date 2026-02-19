import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../shared/models/demand_model.dart';
import '../services/demand_service.dart';
import '../../auth/data/services/auth_service.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';

class DemandDetailPage extends StatefulWidget {
  final Demand demand;

  const DemandDetailPage({
    Key? key,
    required this.demand,
  }) : super(key: key);

  @override
  State<DemandDetailPage> createState() => _DemandDetailPageState();
}

class _DemandDetailPageState extends State<DemandDetailPage> with TickerProviderStateMixin {
  late Demand _demand;
  bool _isLoading = false;
  String? _selectedStatus;
  final TextEditingController _resolutionNotesController = TextEditingController();
  
  late AnimationController _fadeController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _demand = widget.demand;
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _staggeredAnimations = List.generate(
      4,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _fadeController,
          curve: Interval(index * 0.15, 1.0, curve: Curves.easeOutCubic),
        ),
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _resolutionNotesController.dispose();
    super.dispose();
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'password_reset': return 'Security Request';
      case 'hardware': return 'Hardware Support';
      case 'administrative': return 'Admin Request';
      case 'custom': return 'Special Inquiry';
      default: 
        if (type.isEmpty) return 'General Request';
        return type.split('_').map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1)).join(' ');
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending': return 'Awaiting Review';
      case 'approved': return 'Approved';
      case 'rejected': return 'Declined';
      case 'in_progress': return 'In Process';
      case 'resolved': return 'Completed';
      default: return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orangeAccent;
      case 'approved': return const Color(0xFF4CAF50);
      case 'rejected': return const Color(0xFFEF5350);
      case 'in_progress': return Colors.blueAccent;
      case 'resolved': return const Color(0xFF4CAF50);
      default: return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _updateDemandStatusWithNotes(String status, String resolutionNotes) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await AuthService.getCurrentUser();
      final currentUserId = currentUser?['id'];
      
      final updateData = {
        'status': status,
        if (currentUserId != null) 'handledBy': currentUserId,
        'resolutionNotes': resolutionNotes,
      };
      
      final result = await DemandService.updateDemand(_demand.id!, updateData);

      if (result['success']) {
        final refreshedResult = await DemandService.getDemandById(_demand.id!);
        if (refreshedResult['success'] && mounted) {
          setState(() {
            _demand = refreshedResult['data'];
            _selectedStatus = null;
            _resolutionNotesController.clear();
            _isLoading = false;
          });
          
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to ${_getStatusDisplayName(status)}'),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Ticket Details',
        subtitle: 'Reference #${(_demand.id != null && _demand.id!.length >= 8) ? _demand.id!.substring(0, 8) : _demand.id ?? 'Unknown'}',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Badge Section
                      _buildAnimatedSection(0, _buildHeaderCard(isDark)),
                      
                      const SizedBox(height: 20),
                      
                      // Detailed Info Section
                      _buildAnimatedSection(1, _buildDetailsCard(isDark)),
                      
                      const SizedBox(height: 20),
                      
                      // Resolution History (If available)
                      if (_demand.status != 'pending')
                        _buildAnimatedSection(2, _buildResolutionCard(isDark)),
                      
                      const SizedBox(height: 20),
                      
                      // Action Controls (If not resolved)
                      if (_demand.status != 'resolved' && _demand.status != 'rejected')
                        _buildAnimatedSection(3, _buildActionCard(isDark)),
                      
                      const SizedBox(height: 100), // Space for bottom nav
                    ],
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

  Widget _buildHeaderCard(bool isDark) {
    final statusColor = _getStatusColor(_demand.status);
    return _buildGlassContainer(
      isDark: isDark,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Icon(
              _getIconForType(_demand.type),
              color: statusColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTypeDisplayName(_demand.type),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                _buildStatusIndicator(statusColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(bool isDark) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Requester', _demand.requesterName, Icons.person_rounded, isDark),
          const Divider(height: 32, thickness: 0.5),
          _buildDetailRow('Submission Date', _formatDate(_demand.createdAt), Icons.calendar_today_rounded, isDark),
          const Divider(height: 32, thickness: 0.5),
          Text(
            'Inquiry Details',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _demand.description,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionCard(bool isDark) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 10),
              Text(
                'Resolution Protocol',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_demand.handlerName != null)
            _buildDetailRow('Handler', _demand.handlerName!, Icons.badge_rounded, isDark),
          if (_demand.resolutionNotes != null && _demand.resolutionNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Protocol Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(_demand.resolutionNotes!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(bool isDark) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update Administrative Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildStatusDropdown(isDark),
          const SizedBox(height: 20),
          const Text('Internal Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _resolutionNotesController,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Record details about this status transition...',
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [AppTheme.accentGold, Color(0xFF8B6914)]),
                boxShadow: [BoxShadow(color: AppTheme.accentGold.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: ElevatedButton(
                onPressed: () => _updateDemandStatusWithNotes(
                  _selectedStatus ?? _demand.status,
                  _resolutionNotesController.text.trim(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Confirm Protocol Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus ?? _demand.status,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: ['pending', 'approved', 'rejected', 'in_progress', 'resolved']
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(_getStatusDisplayName(s), style: TextStyle(color: _getStatusColor(s), fontWeight: FontWeight.bold)),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _selectedStatus = val),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.accentGold.withOpacity(0.7)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
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

  Widget _buildStatusIndicator(Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        _getStatusDisplayName(_demand.status),
        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'password_reset': return Icons.shield_rounded;
      case 'hardware': return Icons.terminal_rounded;
      case 'administrative': return Icons.description_rounded;
      case 'custom': return Icons.auto_awesome_rounded;
      default: return Icons.help_center_rounded;
    }
  }
}
