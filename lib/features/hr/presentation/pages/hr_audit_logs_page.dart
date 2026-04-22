import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/features/hr/data/services/hr_service.dart';
import 'package:fs_hub/features/hr/data/models/audit_log.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class HrAuditLogsPage extends StatefulWidget {
  const HrAuditLogsPage({super.key});

  @override
  State<HrAuditLogsPage> createState() => _HrAuditLogsPageState();
}

class _HrAuditLogsPageState extends State<HrAuditLogsPage> {
  List<AuditLog> _logs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedAction = '';
  DateTimeRange? _dateRange;
  String? _selectedUserId;
  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await HrService.getAuditLogs(
        limit: 200,
        action: _selectedAction.isNotEmpty ? _selectedAction : null,
        userId: _selectedUserId,
        startDate: _dateRange?.start.toIso8601String().split('T')[0],
        endDate: _dateRange?.end.toIso8601String().split('T')[0],
      );
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AuditLog> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    final q = _searchQuery.toLowerCase();
    return _logs.where((l) =>
        (l.userName?.toLowerCase().contains(q) ?? false) ||
        (l.userEmail?.toLowerCase().contains(q) ?? false) ||
        l.action.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    return LuxuryScaffold(
      title: isFr ? 'Journaux d\'audit' : 'Audit Logs',
      showBackButton: true,
      body: Container(
        color: bg,
        child: Column(
          children: [
            const SizedBox(height: 100),
            _buildSearchBar(isFr, isDark),
            _buildFilters(isFr, isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _gold))
                  : _buildLogList(isFr, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isFr, bool isDark) {
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: isFr ? 'Rechercher dans les résultats…' : 'Search in results…',
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF2F2F2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isFr, bool isDark) {
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: _selectedAction.isEmpty ? (isFr ? 'Action: Toutes' : 'Action: All') : _selectedAction.replaceAll('_', ' '),
                  isActive: _selectedAction.isNotEmpty,
                  onTap: () => _showActionFilter(isFr),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _dateRange == null 
                    ? (isFr ? 'Période' : 'Date Range') 
                    : '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}',
                  isActive: _dateRange != null,
                  onTap: () => _showDateFilter(),
                ),
                const SizedBox(width: 8),
                if (_selectedAction.isNotEmpty || _dateRange != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedAction = '';
                        _dateRange = null;
                      });
                      _fetchLogs();
                    },
                    icon: const Icon(Icons.clear_all_rounded, color: Colors.redAccent, size: 20),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                isFr ? 'Filtres serveurs actifs.' : 'Server-side filters active.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: _fetchLogs,
                icon: const Icon(Icons.refresh_rounded, size: 20, color: _gold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showActionFilter(bool isFr) async {
    final actions = [
      '', 'LOGIN', 'LOGOUT', 'USER_CREATED', 'USER_DELETED', 
      'TASK_CREATED', 'TASK_UPDATED', 'BONUS_GRANTED', 
      'SALARY_CREATED', 'ATTENDANCE_LOGGED'
    ];
    
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: actions.map((a) => ListTile(
          title: Text(a.isEmpty ? (isFr ? 'Toutes les actions' : 'All Actions') : a.replaceAll('_', ' ')),
          selected: _selectedAction == a,
          onTap: () => Navigator.pop(ctx, a),
        )).toList(),
      ),
    );

    if (selected != null) {
      setState(() => _selectedAction = selected);
      _fetchLogs();
    }
  }

  void _showDateFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _gold,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _fetchLogs();
    }
  }

  Widget _buildLogList(bool isFr, bool isDark) {
    if (_filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Aucun journal trouvé' : 'No audit logs found',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      itemCount: _filteredLogs.length,
      itemBuilder: (context, index) {
        final log = _filteredLogs[index];
        return _LogTile(log: log, isDark: isDark, isFr: isFr);
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final AuditLog log;
  final bool isDark, isFr;

  const _LogTile({required this.log, required this.isDark, required this.isFr});

  Color _actionColor(String action) {
    if (action.contains('DELETE')) return Colors.redAccent;
    if (action.contains('CREATE') || action.contains('GRANTED')) return Colors.greenAccent.shade700;
    if (action.contains('UPDATE') || action.contains('SET')) return Colors.orangeAccent.shade700;
    if (action.contains('LOGIN')) return Colors.blueAccent;
    return Colors.grey;
  }

  IconData _actionIcon(String action) {
    if (action.contains('DELETE')) return Icons.delete_forever_rounded;
    if (action.contains('CREATE')) return Icons.add_circle_outline_rounded;
    if (action.contains('UPDATE')) return Icons.edit_note_rounded;
    if (action.contains('LOGIN')) return Icons.login_rounded;
    if (action.contains('BONUS')) return Icons.stars_rounded;
    if (action.contains('SALARY')) return Icons.payments_rounded;
    return Icons.event_note_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final color = _actionColor(log.action);
    final timeStr = DateFormat('HH:mm').format(log.createdAt);
    final dateStr = DateFormat('dd/MM/yyyy').format(log.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_actionIcon(log.action), color: color, size: 24),
        ),
        title: Text(
          log.action.replaceAll('_', ' '),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Row(
          children: [
             CircleAvatar(
                radius: 8,
                backgroundColor: Colors.grey.shade400,
                child: Text(
                  log.userName?.isNotEmpty == true ? log.userName![0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  log.userName ?? log.userId,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$dateStr $timeStr',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  isFr ? 'Détails de l\'action :' : 'Action Details:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: SelectableText(
                    JsonEncoder.withIndent('  ').convert(log.details),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isDark ? Colors.greenAccent.shade100 : Colors.indigo.shade800,
                    ),
                  ),
                ),
                if (log.userEmail != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Email: ${log.userEmail}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'User ID: ${log.userId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFC9A24D);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? gold : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? gold : (isDark ? Colors.white10 : Colors.black12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}
