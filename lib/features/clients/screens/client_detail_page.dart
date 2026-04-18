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
import 'package:fs_hub/features/finance/services/financial_calculation_service.dart';
import 'package:intl/intl.dart';

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
  Map<String, dynamic>? _financialSummary;
  
  late AnimationController _fadeController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    
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
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    final result = await FinancialCalculationService.calculateClientFinancialSummary(_client.id!);
    if (result['success'] && mounted) {
      setState(() {
        _financialSummary = result['data'];
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
                      
                      // Financial Health & Payments
                      _buildAnimatedSection(2, _buildFinancialHealthCard(isDark, settings)),
                      
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

  Widget _buildFinancialHealthCard(bool isDark, SettingsController settings) {
    if (_financialSummary == null) {
      return _buildGlassContainer(
        isDark: isDark,
        child: const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
      );
    }

    final double totalPaid = (_financialSummary!['total_paid'] as num).toDouble();
    final double totalInvoiced = (_financialSummary!['total_invoiced'] as num).toDouble();
    final double outstanding = (_financialSummary!['outstanding_balance'] as num).toDouble();
    final double ratio = (_financialSummary!['payment_ratio'] as num).toDouble();
    
    final Color healthColor = ratio >= 90 ? Colors.green : ratio >= 50 ? Colors.orange : Colors.red;
    final currencyFormat = NumberFormat.currency(symbol: 'DT', decimalDigits: 3);

    return _buildGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accentGold, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'SANTÉ FINANCIÈRE',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: healthColor.withOpacity(0.3)),
                ),
                child: Text(
                  '${ratio.toStringAsFixed(1)}%',
                  style: TextStyle(color: healthColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: _buildFinancialMetric(
                  'Encaissé (Crédit)',
                  currencyFormat.format(totalPaid),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFinancialMetric(
                  'Total Projets',
                  currencyFormat.format(totalInvoiced),
                  isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reste à payer',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(outstanding),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: outstanding > 0 ? Colors.redAccent : Colors.grey,
                    ),
                  ),
                ],
              ),
              Icon(
                outstanding == 0 ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: outstanding == 0 ? Colors.green : Colors.orange,
                size: 28,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalInvoiced > 0 ? (totalPaid / totalInvoiced).clamp(0, 1) : 0,
              backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(healthColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
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


