import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/leave_request_model.dart';
import 'package:intl/intl.dart';
import '../widgets/leave_request_modal.dart';

class HrLeavesPage extends StatefulWidget {
  const HrLeavesPage({super.key});

  @override
  State<HrLeavesPage> createState() => _HrLeavesPageState();
}

class _HrLeavesPageState extends State<HrLeavesPage> {
  List<LeaveRequest> _leaves = [];
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
      final data = await HrService.getLeaveRequests();
      if (mounted) setState(() { _leaves = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int? id, String status) async {
    if (id == null) return;
    final ok = await HrService.updateLeaveStatus(id, status);
    if (ok && mounted) _load();
  }

  int _getEmployeeTotalApproved(String empId) {
    return _leaves
        .where((l) => l.employeeId == empId && l.status == 'approved')
        .fold(0, (sum, l) => sum + (l.totalDays ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    final pending  = _leaves.where((l) => l.status == 'pending').length;
    final approved = _leaves.where((l) => l.status == 'approved').length;

    // Grouping by employee to show balances
    final Map<String, List<LeaveRequest>> byEmp = {};
    for (var l in _leaves) {
      byEmp.putIfAbsent(l.employeeId, () => []).add(l);
    }

    return LuxuryScaffold(
      title: isFr ? 'Gestion des Congés' : 'Leave Management',
      showBackButton: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : SafeArea(
              child: Container(
              color: bg,
              child: Column(
                children: [
                  // Improved Header Stats
                  _StatsBar(
                    isDark: isDark,
                    items: [
                      _StatItem(label: isFr ? 'En attente' : 'Pending', value: pending, color: const Color(0xFFF59E0B)),
                      _StatItem(label: isFr ? 'Approuvés' : 'Approved', value: approved, color: const Color(0xFF22C55E)),
                      _StatItem(label: 'Total', value: _leaves.length, color: _gold),
                    ],
                  ),

                  // Employee Balances Summary (Horizontal list)
                  if (byEmp.isNotEmpty)
                    _BalanceSummary(
                      isDark: isDark,
                      isFr: isFr,
                      employeeLeaves: byEmp,
                    ),

                  Expanded(
                    child: _leaves.isEmpty
                        ? _empty(isFr)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                            itemCount: _leaves.length,
                            itemBuilder: (_, i) {
                              final leave = _leaves[i];
                              final approvedSoFar = _getEmployeeTotalApproved(leave.employeeId);
                              
                              return _LeaveCard(
                                leave: leave,
                                isDark: isDark,
                                isFr: isFr,
                                approvedSoFar: approvedSoFar,
                                onApprove: () => _updateStatus(leave.id, 'approved'),
                                onReject:  () => _updateStatus(leave.id, 'rejected'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const LeaveRequestModal(),
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
        const Icon(Icons.beach_access_rounded, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Text(isFr ? 'Aucune demande' : 'No requests', style: const TextStyle(color: Colors.grey, fontSize: 15)),
      ],
    ),
  );
}

// ─── Balance Summary ─────────────────────────────────────────────────────────

class _BalanceSummary extends StatelessWidget {
  final bool isDark, isFr;
  final Map<String, List<LeaveRequest>> employeeLeaves;

  const _BalanceSummary({required this.isDark, required this.isFr, required this.employeeLeaves});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    return Container(
      height: 110,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151515) : const Color(0xFFF2F2F2),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: employeeLeaves.length,
        itemBuilder: (context, i) {
          final empId = employeeLeaves.keys.elementAt(i);
          final leaves = employeeLeaves[empId]!;
          final name = leaves.first.employeeNom ?? empId;
          final totalApproved = leaves
              .where((l) => l.status == 'approved')
              .fold(0, (sum, l) => sum + (l.totalDays ?? 0));
          
          final isOverLimit = totalApproved > 21;
          final color = isOverLimit ? const Color(0xFFEF4444) : const Color(0xFFB48A38);

          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$totalApproved / 21 j', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                    if (isOverLimit)
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (totalApproved / 21).clamp(0, 1),
                    minHeight: 3,
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Stat Bar ──────────────────────────────────────────────────────────────────

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

// ─── Leave Card ────────────────────────────────────────────────────────────────

class _LeaveCard extends StatelessWidget {
  final LeaveRequest leave;
  final bool isDark, isFr;
  final int approvedSoFar;
  final VoidCallback onApprove, onReject;

  static const _gold = Color(0xFFC9A24D);

  const _LeaveCard({
    required this.leave,
    required this.isDark,
    required this.isFr,
    required this.approvedSoFar,
    required this.onApprove,
    required this.onReject,
  });

  Color get _statusColor {
    switch (leave.status) {
      case 'approved': return const Color(0xFF22C55E);
      case 'rejected': return const Color(0xFFEF4444);
      default:         return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final isPending = leave.status == 'pending';
    
    // Logic: if current approved + this request > 21, show warning
    final totalIfApproved = approvedSoFar + (leave.totalDays ?? 0);
    final willExceed = leave.status == 'pending' && totalIfApproved > 21;
    final isAlreadyDeduced = leave.status == 'approved' && approvedSoFar > 21; // simplified for history

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: willExceed 
            ? const Color(0xFFEF4444).withOpacity(0.3) 
            : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06))
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    (leave.employeeNom ?? leave.employeeId).isNotEmpty
                        ? (leave.employeeNom ?? leave.employeeId)[0].toUpperCase()
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
                      '${leave.employeePrenom ?? ""} ${leave.employeeNom ?? leave.employeeId}'.trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      leave.leaveType.toUpperCase(),
                      style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  leave.status.toUpperCase(),
                  style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Leave Info & Balance
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 13, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${DateFormat.yMMMd().format(leave.startDate)} → ${DateFormat.yMMMd().format(leave.endDate)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${leave.totalDays ?? 0} ${isFr ? "jours" : "days"}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),

          // Deduction Warning
          if (willExceed || isAlreadyDeduced) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFr 
                        ? 'Dépassement du quota (21j). Déduction de salaire appliquée.' 
                        : 'Quota exceeded (21d). Salary deduction applied.',
                      style: const TextStyle(
                        color: Color(0xFFEF4444), 
                        fontSize: 11, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (leave.reason != null && leave.reason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              leave.reason!,
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
                  child: _ActionBtn(
                    label: isFr ? 'Approuver' : 'Approve',
                    icon: Icons.check_rounded,
                    color: const Color(0xFF22C55E),
                    onTap: onApprove,
                    filled: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: isFr ? 'Refuser' : 'Reject',
                    icon: Icons.close_rounded,
                    color: const Color(0xFFEF4444),
                    onTap: onReject,
                    filled: false,
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

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap, required this.filled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(filled ? 0 : 0.4)),
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
