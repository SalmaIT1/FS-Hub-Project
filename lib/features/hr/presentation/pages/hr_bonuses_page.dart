import 'package:flutter/material.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/bonus_model.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';

import 'package:fs_hub/features/hr/presentation/widgets/grant_bonus_modal.dart';

class HrBonusesPage extends StatefulWidget {
  const HrBonusesPage({super.key});

  @override
  State<HrBonusesPage> createState() => _HrBonusesPageState();
}

class _HrBonusesPageState extends State<HrBonusesPage> {
  List<Bonus> _bonuses = [];
  bool _isLoading = true;
  String? _currentUserRole;
  String? _currentUserId;

  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        _currentUserRole = user['role']?.toString();
        _currentUserId = user['id']?.toString();
        
        // Logical scoping: Admin/RH/Comptable see all bonuses; Employees see only their own.
        final isAdminOrHR = _currentUserRole == 'Admin' || _currentUserRole == 'RH' || _currentUserRole == 'Comptable';
        final data = await HrService.getBonuses(employeeId: isAdminOrHR ? null : _currentUserId);
        
        if (mounted) setState(() { _bonuses = data; _isLoading = false; });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showGrantBonusModal(bool isFr) async {
    final res = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GrantBonusModal(isFr: isFr),
    );
    if (res == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();
    final isFr = settings.languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    final isAdminOrHR = _currentUserRole == 'Admin' || _currentUserRole == 'RH' || _currentUserRole == 'Comptable';

    return LuxuryScaffold(
      title: isFr ? 'Primes & Bonus' : 'Bonuses & Perks',
      showBackButton: true,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _gold))
        : Container(
            color: bg,
            child: Column(
              children: [
                const SizedBox(height: 100),
                 // Summary stats if Admin/HR
                if (isAdminOrHR && _bonuses.isNotEmpty) 
                  _ManagerStats(isDark: isDark, isFr: isFr, bonuses: _bonuses),
                
                Expanded(
                  child: _bonuses.isEmpty
                    ? _buildEmptyState(isFr, isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
                        itemCount: _bonuses.length,
                        itemBuilder: (ctx, i) => _buildBonusCard(_bonuses[i], isDark, isFr, isAdminOrHR),
                      ),
                ),
              ],
            ),
          ),
      floatingActionButton: (isAdminOrHR)
        ? FloatingActionButton(
            onPressed: () => _showGrantBonusModal(isFr),
            backgroundColor: _gold,
            elevation: 4,
            child: const Icon(Icons.stars_rounded, color: Colors.white),
          )
        : null,
    );
  }

  Widget _buildEmptyState(bool isFr, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stars_rounded, size: 64, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 20),
          Text(
            isFr ? 'Aucun bonus enregistré' : 'No bonuses found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusCard(Bonus b, bool isDark, bool isFr, bool isAdminOrHR) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final name = '${b.employeePrenom ?? ""} ${b.employeeNom ?? b.employeeId}'.trim();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.military_tech_rounded, color: _gold, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAdminOrHR)
                  Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  ),
                Text(
                  b.bonusType.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _gold),
                ),
                if (b.reason != null && b.reason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      b.reason!,
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${b.amount.toStringAsFixed(3)} DT',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
              ),
              if (b.grantedDate != null)
                Text(
                  DateFormat.yMMMd().format(b.grantedDate!),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagerStats extends StatelessWidget {
  final bool isDark, isFr;
  final List<Bonus> bonuses;

  const _ManagerStats({required this.isDark, required this.isFr, required this.bonuses});

  @override
  Widget build(BuildContext context) {
    final total = bonuses.fold(0.0, (sum, b) => sum + b.amount);
    final count = bonuses.length;
    final surface = isDark ? const Color(0xFF161616) : Colors.white;

    return Container(
      color: surface,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _statBox(isFr ? 'Total versé' : 'Total Paid', '${total.toStringAsFixed(3)} DT', isDark),
          const SizedBox(width: 12),
          _statBox(isFr ? 'Nb Primes' : 'Bonus Count', '$count', isDark),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
