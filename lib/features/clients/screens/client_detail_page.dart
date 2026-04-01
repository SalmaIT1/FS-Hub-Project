import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../models/client_model.dart';
import '../services/client_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';
import 'client_form_page.dart';

class ClientDetailPage extends StatefulWidget {
  final Client client;

  const ClientDetailPage({
    super.key,
    required this.client,
  });

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> with TickerProviderStateMixin {
  late Client _client;
  bool _isLoading = false;
  final TextEditingController _scoreController = TextEditingController();
  
  late AnimationController _fadeController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _scoreController.text = _client.scoreCredit.toString();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _staggeredAnimations = List.generate(
      5,
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
    _scoreController.dispose();
    super.dispose();
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreDescription(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Poor';
  }

  Future<void> _updateScore() async {
    final newScore = int.tryParse(_scoreController.text);
    if (newScore == null || newScore < 0 || newScore > 100) return;

    setState(() => _isLoading = true);

    try {
      final result = await ClientService.updateClientScore(_client.id!, newScore);

      if (result['success'] && mounted) {
        setState(() {
          _client = result['data'];
          _isLoading = false;
        });
        
        LuxuryStatusDialog.show(
          context,
          isSuccess: true,
          title: 'Metrical Adjustment',
          message: 'Client credit score has been recalculated and synchronized.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Sync Fault',
          message: 'Failed to update credit metric: $e',
        );
      }
    }
  }

  Future<void> _deleteClient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this client? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await ClientService.deleteClient(_client.id!);

      if (result['success'] && mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: true,
          title: 'Entity Purged',
          message: 'Target client record has been wiped from the central registry.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Purge Error',
          message: 'Registry integrity check failed during removal: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context, listen: false);

    return Scaffold(
      appBar: LuxuryAppBar(
        title: settings.translate('client_details'),
        subtitle: 'ID: ${_client.id}',
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
                      // Header Card with Client Info
                      _buildAnimatedSection(0, _buildHeaderCard(isDark, settings)),
                      
                      const SizedBox(height: 20),
                      
                      // Contact Information
                      _buildAnimatedSection(1, _buildContactCard(isDark, settings)),
                      
                      const SizedBox(height: 20),
                      
                      // Credit Score Management
                      _buildAnimatedSection(2, _buildCreditScoreCard(isDark, settings)),
                      
                      const SizedBox(height: 20),
                      
                      // Actions
                      _buildAnimatedSection(3, _buildActionsCard(isDark, settings)),
                      
                      const SizedBox(height: 100),
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

  Widget _buildHeaderCard(bool isDark, SettingsController settings) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Row(
        children: [
          // Avatar/Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _client.type == ClientType.entreprise
                    ? [AppTheme.accentGold, const Color(0xFF8B6914)]
                    : [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              _client.type == ClientType.entreprise ? Icons.business_rounded : Icons.person_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 24),
          
          // Client Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _client.displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _client.type == ClientType.entreprise
                        ? AppTheme.accentGold.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _client.type == ClientType.entreprise
                          ? AppTheme.accentGold.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _client.type.displayName,
                    style: TextStyle(
                      color: _client.type == ClientType.entreprise ? AppTheme.accentGold : Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(bool isDark, SettingsController settings) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contact_page_rounded, color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 10),
              Text(
                settings.translate('contact_information'),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_client.email != null)
            _buildDetailRow('Email', _client.email!, Icons.email_rounded, isDark),
          
          if (_client.email != null) const Divider(height: 32, thickness: 0.5),
          
          if (_client.telephone != null)
            _buildDetailRow('Phone', _client.telephone!, Icons.phone_rounded, isDark),
          
          if (_client.raisonSociale != null && _client.raisonSociale!.isNotEmpty) ...[
            if (_client.telephone != null) const Divider(height: 32, thickness: 0.5),
            _buildDetailRow('Company', _client.raisonSociale!, Icons.business_rounded, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCreditScoreCard(bool isDark, SettingsController settings) {
    final scoreColor = _getScoreColor(_client.scoreCredit);
    
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.score_rounded, color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 10),
              Text(
                settings.translate('credit_score'),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Current Score Display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scoreColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Score',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _client.scoreCredit.toString(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getScoreDescription(_client.scoreCredit),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _client.scoreCredit / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scoreColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Update Score Form
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scoreController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'New Score (0-100)',
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
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [AppTheme.accentGold, Color(0xFF8B6914)]),
                ),
                child: IconButton(
                  onPressed: _updateScore,
                  icon: const Icon(Icons.update_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(bool isDark, SettingsController settings) {
    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.translate('actions'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [AppTheme.accentGold, Color(0xFF8B6914)]),
                    boxShadow: [BoxShadow(color: AppTheme.accentGold.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ClientFormPage(client: _client)),
                    ).then((_) => Navigator.pop(context, true)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Edit Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: ElevatedButton(
                    onPressed: _deleteClient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
}


