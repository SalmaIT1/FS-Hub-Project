import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../shared/models/demand_model.dart';
import '../services/demand_service.dart';
import '../../../widgets/demand_card.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/services/auth_service.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/state/settings_controller.dart';
import 'demand_detail_page.dart';

class DemandsListPage extends StatefulWidget {
  const DemandsListPage({super.key});

  @override
  State<DemandsListPage> createState() => _DemandsListPageState();
}

class _DemandsListPageState extends State<DemandsListPage> with SingleTickerProviderStateMixin {
  List<Demand> _demands = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async => _loadDemands();

  Future<void> _loadDemands() async {
    setState(() => _isLoading = true);
    try {
      final result = await DemandService.getAllDemands(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        type: _selectedType == 'all' ? null : _selectedType,
      );

      if (result['success'] && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        if (data['success'] && data['data'] != null) {
          final demandsList = data['data'] as List;
          setState(() {
            _demands = demandsList
                .map((json) => Demand.fromJson(json as Map<String, dynamic>))
                .toList();
            _isLoading = false;
          });
          _listController.forward(from: 0);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: LuxuryAppBar(
        title: settings.translate('system_demands'),
        subtitle: settings.translate('demands_subtitle'),
        showBackButton: Navigator.canPop(context),
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
        child: RefreshIndicator(
          color: AppTheme.accentGold,
          onRefresh: _loadDemands,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Summary Stats
              SliverToBoxAdapter(child: _buildSummaryCard(isDark, settings)),
              
              // Search/Filter Bar
              SliverToBoxAdapter(child: _buildFilterSection(isDark, settings)),

              // List of demands
              _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
                    )
                  : _demands.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState(isDark, settings))
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _listController,
                                    curve: Interval(
                                      (index / 10).clamp(0.0, 1.0),
                                      1.0,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                                );

                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) => Opacity(
                                    opacity: animation.value,
                                    child: Transform.translate(
                                      offset: Offset(0, 30 * (1 - animation.value)),
                                      child: child,
                                    ),
                                  ),
                                  child: DemandCard(
                                    demand: _demands[index],
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DemandDetailPage(demand: _demands[index]),
                                      ),
                                    ).then((_) => _loadDemands()),
                                  ),
                                );
                              },
                              childCount: _demands.length,
                            ),
                          ),
                        ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(settings),
    );
  }

  Widget _buildSummaryCard(bool isDark, SettingsController settings) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppTheme.accentGold.withOpacity(0.15), Colors.white.withOpacity(0.05)]
              : [AppTheme.accentGold.withOpacity(0.1), Colors.black.withOpacity(0.02)],
        ),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(settings.translate('total'), _demands.length.toString(), Icons.assignment_rounded),
          Container(width: 1, height: 40, color: AppTheme.accentGold.withOpacity(0.1)),
          _buildStatItem(settings.translate('pending'), _demands.where((d) => d.status == 'pending').length.toString(), Icons.hourglass_empty_rounded),
          Container(width: 1, height: 40, color: AppTheme.accentGold.withOpacity(0.1)),
          _buildStatItem(settings.translate('resolved'), _demands.where((d) => d.status == 'resolved').length.toString(), Icons.check_circle_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accentGold, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildFilterSection(bool isDark, SettingsController settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildDropDown(settings.translate('status'), _selectedStatus, ['all', 'pending', 'in_progress', 'resolved', 'rejected'], (val) {
              setState(() => _selectedStatus = val!);
              _loadDemands();
            }, isDark, settings),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDropDown(settings.translate('type'), _selectedType, ['all', 'password_reset', 'hardware', 'administrative', 'custom'], (val) {
              setState(() => _selectedType = val!);
              _loadDemands();
            }, isDark, settings),
          ),
        ],
      ),
    );
  }

  Widget _buildDropDown(String hint, String value, List<String> items, Function(String?) onChanged, bool isDark, SettingsController settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(settings.translate(item)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, SettingsController settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 80, color: AppTheme.accentGold.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(settings.translate('crystal_clear'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text(settings.translate('no_demands_filter'), style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildFAB(SettingsController settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 90),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [AppTheme.accentGold, Color(0xFF8B6914)]),
        boxShadow: [BoxShadow(color: AppTheme.accentGold.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'fab_demands',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.createDemand).then((_) => _loadDemands()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: Text(settings.translate('create_ticket'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
