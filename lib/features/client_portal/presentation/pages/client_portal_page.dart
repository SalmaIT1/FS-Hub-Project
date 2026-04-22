import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/features/finance/services/finance_service.dart';
import 'package:fs_hub/features/projects/services/project_service.dart';
import 'package:fs_hub/shared/models/finance_model.dart';
import 'package:fs_hub/shared/models/project_model.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'package:fs_hub/features/chat/presentation/pages/conversation_list_page.dart' as chat_ui;

class ClientPortalPage extends StatefulWidget {
  const ClientPortalPage({super.key});

  @override
  State<ClientPortalPage> createState() => _ClientPortalPageState();
}

class _ClientPortalPageState extends State<ClientPortalPage> with SingleTickerProviderStateMixin {
  String _userName = 'Client';
  bool _isLoading = true;
  List<Quote> _quotes = [];
  List<Project> _projects = [];
  List<Invoice> _invoices = [];
  Map<String, dynamic> _financeSummary = {};
  String? _activeView; // null = Dashboard, 'projects', 'quotes', 'invoices'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        AuthService.getGreetingName().catchError((e) => 'Client'),
        FinanceService.getMyQuotes().catchError((e) => <Quote>[]),
        ProjectService.getMyProjects().catchError((e) => <Project>[]),
        FinanceService.getMyInvoices().catchError((e) => <Invoice>[]),
        FinanceService.getMyFinanceSummary().catchError((e) => <String, dynamic>{}),
      ]);
      
      if (mounted) {
        setState(() {
          _userName = results[0] as String;
          _quotes = results[1] as List<Quote>;
          _projects = results[2] as List<Project>;
          _invoices = results[3] as List<Invoice>;
          _financeSummary = results[4] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();
    final isFr = settings.languageCode == 'fr';
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth > 1200 ? screenWidth * 0.12 : (screenWidth > 800 ? screenWidth * 0.08 : 24.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LuxuryAppBar(
        title: 'FS HUB',
        subtitle: isFr ? 'Espace Exécutif' : 'Executive Workspace',
        isPremium: true,
        showBackButton: _activeView != null,
        onBackPress: _activeView != null ? () => setState(() => _activeView = null) : null,
        showDefaultActions: true,
      ),
      body: Stack(
        children: [
          // Ambient Background (Mirrored from HomePage)
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF030303), Color(0xFF0A0A0A), Color(0xFF000000)])
                  : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEDE8DF), Color(0xFFE4DDD3), Color(0xFFDBD4C8)]),
            ),
          ),
          if (isDark) ...[
            Positioned(top: -150, right: -100, child: _AmbientOrb(color: const Color(0xFFC9A24D).withOpacity(0.12), size: 400)),
            Positioned(bottom: 200, left: -150, child: _AmbientOrb(color: const Color(0xFFC9A24D).withOpacity(0.06), size: 500)),
          ] else ...[
            Positioned(top: -200, right: -100, child: _AmbientOrb(color: const Color(0xFFC9A24D).withOpacity(0.15), size: 450)),
          ],

          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC9A24D)))
            : SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 30),
                      if (_activeView == null) ..._buildDashboard(isDark, isFr, settings)
                      else if (_activeView == 'projects') _buildProjectsList()
                      else if (_activeView == 'quotes') _buildQuotesList()
                      else if (_activeView == 'invoices') _buildInvoicesList(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  List<Widget> _buildDashboard(bool isDark, bool isFr, SettingsController settings) {
    final outstanding = double.tryParse(_financeSummary['outstanding']?.toString() ?? '0') ?? 0.0;
    final paid = double.tryParse(_financeSummary['total_paid']?.toString() ?? '0') ?? 0.0;
    final formatter = NumberFormat.currency(locale: 'fr_TN', symbol: 'DT', decimalDigits: 3);

    return [
      _PortalHeroBanner(
        isDark: isDark,
        isFr: isFr,
        name: _userName,
        stat1Value: formatter.format(outstanding),
        stat1Label: isFr ? 'Solde dû' : 'Due',
        stat2Value: formatter.format(paid),
        stat2Label: isFr ? 'Total payé' : 'Paid',
      ),
      const SizedBox(height: 50),
      _PortalSectionDivider(isDark: isDark, label: isFr ? 'VOTRE ACTIVITÉ' : 'YOUR ACTIVITY'),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        int cols = w > 600 ? 2 : 1;
        const gap = 20.0;
        final cardW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _PortalModuleCard(
              title: isFr ? 'Projets' : 'Projects',
              caption: isFr ? 'Labos actifs' : 'Active Labs',
              icon: Icons.science_outlined,
              isDark: isDark,
              width: cardW,
              count: _projects.length > 0 ? _projects.length : null,
              onTap: () => setState(() => _activeView = 'projects'),
            ),
            _PortalModuleCard(
              title: isFr ? 'Devis' : 'Quotes',
              caption: isFr ? 'Dossiers à approuver' : 'Pending Approval',
              icon: Icons.description_outlined,
              isDark: isDark,
              width: cardW,
              count: _quotes.where((q) => q.statut.toLowerCase().contains('envoy')).length > 0 
                  ? _quotes.where((q) => q.statut.toLowerCase().contains('envoy')).length 
                  : null,
              onTap: () => setState(() => _activeView = 'quotes'),
            ),
            _PortalModuleCard(
              title: isFr ? 'Factures' : 'Invoices',
              caption: isFr ? 'Règlements & Reçus' : 'Settlements',
              icon: Icons.receipt_long_outlined,
              isDark: isDark,
              width: cardW,
              count: _invoices.where((i) => i.statut != 'Payée').length > 0 
                  ? _invoices.where((i) => i.statut != 'Payée').length 
                  : null,
              onTap: () => setState(() => _activeView = 'invoices'),
            ),
            _PortalModuleCard(
              title: isFr ? 'Messages' : 'Messages',
              caption: isFr ? 'Support & Équipe' : 'Support & Team',
              icon: Icons.chat_bubble_outline,
              isDark: isDark,
              width: cardW,
              onTap: () => Navigator.pushNamed(context, '/chat'),
            ),
          ],
        );
      }),
    ];
  }

  Widget _buildProjectsList() {
    if (_projects.isEmpty) return _buildEmptyState('Aucun projet en cours', Icons.rocket_outlined);
    return Column(
      children: _projects.map((p) => _buildProjectListItem(p)).toList(),
    );
  }

  Widget _buildProjectListItem(Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.projectDetail, arguments: {'project': project}),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFC9A24D).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.science_outlined, color: Color(0xFFC9A24D), size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(project.statut, style: TextStyle(color: _getStatusColor(project.statut), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotesList() {
    if (_quotes.isEmpty) return _buildEmptyState('Aucun devis disponible', Icons.description_outlined);
    return Column(
      children: _quotes.map((q) => _buildQuoteListItem(q)).toList(),
    );
  }

  Widget _buildQuoteListItem(Quote quote) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatter = NumberFormat.currency(locale: 'fr_TN', symbol: 'DT', decimalDigits: 3);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Devis ${quote.numeroDevis}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              _buildStatusBadge(quote.statut),
            ],
          ),
          const SizedBox(height: 12),
          Text(formatter.format(quote.montantTtc), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: Color(0xFFC9A24D))),
          if (quote.statut.toLowerCase().contains('envoy')) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _approveQuote(quote),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A24D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text('APPROUVER'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoicesList() {
    if (_invoices.isEmpty) return _buildEmptyState('Aucune facture trouvée', Icons.receipt_long_outlined);
    return Column(
      children: _invoices.map((i) => _buildInvoiceListItem(i)).toList(),
    );
  }

  Widget _buildInvoiceListItem(Invoice invoice) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatter = NumberFormat.currency(locale: 'fr_TN', symbol: 'DT', decimalDigits: 3);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Facture ${invoice.numeroFacture}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(invoice.statut, style: TextStyle(color: _getStatusColor(invoice.statut), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(formatter.format(invoice.montantTtc), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          TextButton(onPressed: () => setState(() => _activeView = null), child: const Text('RETOUR')),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase().contains('pay')) return Colors.green;
    if (status.toLowerCase().contains('cours') || status.toLowerCase().contains('envoy')) return Colors.blue;
    if (status.toLowerCase().contains('annul') || status.toLowerCase().contains('refus')) return Colors.red;
    return Colors.grey;
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Future<void> _approveQuote(Quote quote) async {
    // Basic approval logic
    setState(() => _isLoading = true);
    final result = await FinanceService.approveQuote(quote.id!);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis approuvé !'), backgroundColor: Colors.green));
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'approbation.'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }
}

// ── CUSTOM COMPONENTS MATCHING HOMEPAGE ───────────────────────────

class _AmbientOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _AmbientOrb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
    );
  }
}

class _PortalHeroBanner extends StatelessWidget {
  final bool isDark;
  final bool isFr;
  final String name;
  final String stat1Value;
  final String stat1Label;
  final String stat2Value;
  final String stat2Label;

  const _PortalHeroBanner({
    required this.isDark,
    required this.isFr,
    required this.name,
    required this.stat1Value,
    required this.stat1Label,
    required this.stat2Value,
    required this.stat2Label,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF5F0E8).withOpacity(0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFC9A24D).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr ? 'ESPACE EXÉCUTIF' : 'EXECUTIVE WORKSPACE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4.0,
                  color: isDark ? const Color(0xFFC9A24D) : const Color(0xFF90712B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$name.',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  height: 1.1,
                  letterSpacing: -1.0,
                  color: isDark ? Colors.white : const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _LuxStatPill(isDark: isDark, icon: Icons.account_balance_wallet_outlined, value: stat1Value, label: stat1Label, accent: const Color(0xFFC9A24D)),
                  _LuxStatPill(isDark: isDark, icon: Icons.check_circle_outline, value: stat2Value, label: stat2Label, accent: Colors.blueAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalSectionDivider extends StatelessWidget {
  final bool isDark;
  final String label;
  const _PortalSectionDivider({required this.isDark, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 4.0, color: isDark ? const Color(0xFFC9A24D) : const Color(0xFF90712B))),
        const SizedBox(width: 16),
        Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [isDark ? const Color(0xFFC9A24D).withOpacity(0.3) : const Color(0xFF90712B).withOpacity(0.2), Colors.transparent])))),
      ],
    );
  }
}

class _PortalModuleCard extends StatelessWidget {
  final String title;
  final String caption;
  final IconData icon;
  final bool isDark;
  final double width;
  final int? count;
  final VoidCallback onTap;

  const _PortalModuleCard({
    required this.title,
    required this.caption,
    required this.icon,
    required this.isDark,
    required this.width,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width,
        height: 180,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFC9A24D).withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFC9A24D).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: const Color(0xFFC9A24D), size: 24),
                ),
                if (count != null && count! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(100)),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(caption, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LuxStatPill extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _LuxStatPill({required this.isDark, required this.icon, required this.value, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.1), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 12),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
