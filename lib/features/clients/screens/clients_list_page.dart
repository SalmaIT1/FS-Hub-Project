import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../models/client_model.dart';
import '../services/client_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'client_detail_page.dart';
import 'client_form_page.dart';

class ClientsListPage extends StatefulWidget {
  const ClientsListPage({super.key});

  @override
  State<ClientsListPage> createState() => _ClientsListPageState();
}

class _ClientsListPageState extends State<ClientsListPage> with SingleTickerProviderStateMixin {
  List<Client> _clients = [];
  bool _isLoading = true;
  String _selectedType = 'all';
  String _searchQuery = '';
  late AnimationController _listController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadClients();
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final result = await ClientService.getAllClients(
        type: _selectedType == 'all' ? null : _selectedType,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (result['success'] && mounted) {
        final data = result['data'];
        if (data is List) {
          setState(() {
            _clients = data
                .map((json) => Client.fromJson(json as Map<String, dynamic>))
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
        title: settings.translate('clients'),
        subtitle: settings.translate('clients_subtitle'),
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
          onRefresh: _loadClients,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Summary Stats
              SliverToBoxAdapter(child: _buildSummaryCard(isDark, settings)),
              
              // Search and Filter Bar
              SliverToBoxAdapter(child: _buildSearchFilterSection(isDark, settings)),

              // List of clients
              _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
                    )
                  : _clients.isEmpty
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
                                  child: _buildClientCard(_clients[index], isDark, settings),
                                );
                              },
                              childCount: _clients.length,
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
    final entrepriseCount = _clients.where((c) => c.type == ClientType.entreprise).length;
    final particulierCount = _clients.where((c) => c.type == ClientType.particulier).length;
    
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
          _buildStatItem(settings.translate('total'), _clients.length.toString(), Icons.people_rounded),
          Container(width: 1, height: 40, color: AppTheme.accentGold.withOpacity(0.1)),
          _buildStatItem(settings.translate('entreprise'), entrepriseCount.toString(), Icons.business_rounded),
          Container(width: 1, height: 40, color: AppTheme.accentGold.withOpacity(0.1)),
          _buildStatItem(settings.translate('particulier'), particulierCount.toString(), Icons.person_rounded),
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

  Widget _buildSearchFilterSection(bool isDark, SettingsController settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchQuery = value;
                Future.delayed(const Duration(milliseconds: 500), _loadClients);
              },
              decoration: InputDecoration(
                hintText: settings.translate('search_clients'),
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.accentGold.withOpacity(0.7)),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
              ),
            ),
          ),
          
          // Filter Dropdown
          Row(
            children: [
              Expanded(
                child: _buildDropDown(
                  settings.translate('type'), 
                  _selectedType, 
                  ['all', 'entreprise', 'particulier'], 
                  (val) {
                    setState(() => _selectedType = val!);
                    _loadClients();
                  }, 
                  isDark, 
                  settings
                ),
              ),
            ],
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
              child: Text(item == 'all' ? settings.translate('all') : item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildClientCard(Client client, bool isDark, SettingsController settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            ),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientDetailPage(client: client),
                ),
              ).then((_) => _loadClients()),
              child: Row(
                children: [
                  // Avatar/Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: client.type == ClientType.entreprise
                            ? [AppTheme.accentGold, const Color(0xFF8B6914)]
                            : [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      client.type == ClientType.entreprise ? Icons.business_rounded : Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Client Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (client.email != null)
                          Text(
                            client.email!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        if (client.telephone != null)
                          Text(
                            client.telephone!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Score Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getScoreColor(client.scoreCredit).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getScoreColor(client.scoreCredit).withOpacity(0.3)),
                    ),
                    child: Text(
                      client.scoreCredit.toString(),
                      style: TextStyle(
                        color: _getScoreColor(client.scoreCredit),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildEmptyState(bool isDark, SettingsController settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: AppTheme.accentGold.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(settings.translate('no_clients'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text(settings.translate('no_clients_filter'), style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
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
        heroTag: 'fab_clients',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ClientFormPage()),
        ).then((_) => _loadClients()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(settings.translate('add_client'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}


