import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/remote_work_model.dart';
import 'package:intl/intl.dart';
import '../widgets/remote_work_request_modal.dart';

class HrRemoteWorkPage extends StatefulWidget {
  const HrRemoteWorkPage({super.key});

  @override
  State<HrRemoteWorkPage> createState() => _HrRemoteWorkPageState();
}

class _HrRemoteWorkPageState extends State<HrRemoteWorkPage> {
  List<RemoteWork> _requests = [];
  bool _isLoading = true;

  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await HrService.getRemoteWorkRequests();
      if (mounted) setState(() { _requests = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int? id, String status) async {
    if (id == null) return;
    await HrService.updateRemoteWorkStatus(id, status);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);
    
    final pending = _requests.where((r) => r.status == 'pending').length;
    final approved = _requests.where((r) => r.status == 'approved').length;

    return LuxuryScaffold(
      title: isFr ? 'Télétravail' : 'Remote Work',
      showBackButton: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : Container(
              color: bg,
              child: Column(
                children: [
                   const SizedBox(height: 100),
                   // Premium Stats Bar
                  _StatsBar(
                    isDark: isDark,
                    items: [
                      _StatItem(label: isFr ? 'En attente' : 'Pending', value: pending, color: const Color(0xFFF59E0B)),
                      _StatItem(label: isFr ? 'Approuvés' : 'Approved', value: approved, color: const Color(0xFF22C55E)),
                      _StatItem(label: 'Total', value: _requests.length, color: _gold),
                    ],
                  ),

                  // Quota Info Banner (Premium Style)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _gold.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: _gold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isFr 
                              ? 'Politique : Maximum 3 jours de télétravail par semaine.' 
                              : 'Policy: Maximum 3 days of remote work per week.',
                            style: const TextStyle(
                              color: _gold, 
                              fontSize: 12, 
                              fontWeight: FontWeight.w600
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _requests.isEmpty
                        ? _empty(isFr)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: _requests.length,
                            itemBuilder: (_, i) => _RemoteCard(
                              request: _requests[i],
                              isDark: isDark,
                              isFr: isFr,
                              onApprove: () => _updateStatus(_requests[i].id, 'approved'),
                              onReject: () => _updateStatus(_requests[i].id, 'rejected'),
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const RemoteWorkRequestModal(),
          );
          if (res == true) _load();
        },
        backgroundColor: _gold,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _empty(bool isFr) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.home_work_outlined, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Text(
          isFr ? 'Aucune demande' : 'No requests',
          style: const TextStyle(color: Colors.grey, fontSize: 15),
        ),
      ],
    ),
  );
}

// ─── Stat Bar Components ──────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final int value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});
}

class _StatsBar extends StatelessWidget {
  final bool isDark;
  final List<_StatItem> items;
  const _StatsBar({required this.isDark, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: items.map((item) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Text(
                  '${item.value}',
                  style: TextStyle(color: item.color, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(item.label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ─── Remote Card ──────────────────────────────────────────────────────────────

class _RemoteCard extends StatelessWidget {
  final RemoteWork request;
  final bool isDark, isFr;
  final VoidCallback onApprove, onReject;

  static const _gold = Color(0xFFC9A24D);

  const _RemoteCard({
    required this.request,
    required this.isDark,
    required this.isFr,
    required this.onApprove,
    required this.onReject,
  });

  Color get _statusColor {
    switch (request.status) {
      case 'approved': return const Color(0xFF22C55E);
      case 'rejected': return const Color(0xFFEF4444);
      default:         return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final isPending = request.status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    (request.employeeNom ?? request.employeeId).isNotEmpty
                        ? (request.employeeNom ?? request.employeeId)[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.employeePrenom ?? ""} ${request.employeeNom ?? request.employeeId}'.trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      request.type.toUpperCase(),
                      style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 13, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                DateFormat.yMMMd().format(request.remoteDate),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          if (request.reason != null && request.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.reason!,
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Btn(
                    label: isFr ? 'Approuver' : 'Approve',
                    icon: Icons.check_rounded,
                    color: const Color(0xFF22C55E),
                    filled: true,
                    onTap: onApprove,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Btn(
                    label: isFr ? 'Refuser' : 'Reject',
                    icon: Icons.close_rounded,
                    color: const Color(0xFFEF4444),
                    filled: false,
                    onTap: onReject,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _Btn({required this.label, required this.icon, required this.color, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(filled ? 0 : 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: filled ? Colors.white : color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
