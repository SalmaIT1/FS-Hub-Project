import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import 'package:fs_hub/features/employees/services/employee_service.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/attendance_model.dart';
import 'package:intl/intl.dart';

class HrAttendancePage extends StatefulWidget {
  const HrAttendancePage({super.key});

  @override
  State<HrAttendancePage> createState() => _HrAttendancePageState();
}

class _HrAttendancePageState extends State<HrAttendancePage> {
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  Map<String, String> _todayStatus = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchCtrl = TextEditingController();

  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredEmployees = q.isEmpty
          ? _employees
          : _employees.where((e) =>
              e.nom.toLowerCase().contains(q) ||
              e.prenom.toLowerCase().contains(q) ||
              e.poste.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final emps = await EmployeeService.getAllEmployees();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final attendanceList = await HrService.getAllAttendance(dateStr);
      final Map<String, String> statusMap = {};
      for (var r in attendanceList) {
        statusMap[r.employeeId] = r.status;
      }
      if (mounted) {
        setState(() {
          _employees = emps;
          _filteredEmployees = emps;
          _todayStatus = statusMap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAttendance(String empId, String status) async {
    final record = Attendance(
      employeeId: empId,
      attendanceDate: _selectedDate,
      status: status,
    );
    final ok = await HrService.logAttendance(record);
    if (ok && mounted) setState(() => _todayStatus[empId] = status);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF22C55E);
      case 'late':    return const Color(0xFFF59E0B);
      case 'absent':  return const Color(0xFFEF4444);
      case 'remote':  return const Color(0xFF3B82F6);
      default:        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    return LuxuryScaffold(
      title: isFr ? 'Registre de Présence' : 'Attendance',
      showBackButton: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : Container(
              color: bg,
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  _Header(
                    isFr: isFr,
                    isDark: isDark,
                    selectedDate: _selectedDate,
                    searchCtrl: _searchCtrl,
                    todayStatus: _todayStatus,
                    totalEmployees: _employees.length,
                    onDateTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: ThemeData().colorScheme.copyWith(primary: _gold),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadData();
                      }
                    },
                  ),
                  Expanded(
                    child: _filteredEmployees.isEmpty
                        ? _emptyState(isFr)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                            itemCount: _filteredEmployees.length,
                            itemBuilder: (_, i) => _EmployeeRow(
                              employee: _filteredEmployees[i],
                              status: _todayStatus[_filteredEmployees[i].id] ?? 'none',
                              isDark: isDark,
                              isFr: isFr,
                              statusColor: _statusColor,
                              onMark: _markAttendance,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _emptyState(bool isFr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_search_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            isFr ? 'Aucun résultat' : 'No results',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isFr, isDark;
  final DateTime selectedDate;
  final TextEditingController searchCtrl;
  final Map<String, String> todayStatus;
  final int totalEmployees;
  final VoidCallback onDateTap;

  static const _gold = Color(0xFFC9A24D);

  const _Header({
    required this.isFr,
    required this.isDark,
    required this.selectedDate,
    required this.searchCtrl,
    required this.todayStatus,
    required this.totalEmployees,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final present = todayStatus.values.where((s) => s == 'present').length;
    final late    = todayStatus.values.where((s) => s == 'late').length;
    final absent  = todayStatus.values.where((s) => s == 'absent').length;
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '$totalEmployees ${isFr ? "employés" : "employees"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 16, color: _gold),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: const TextStyle(color: _gold, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stat chips — minimal, one row
          Row(
            children: [
              _chip(isFr ? 'Présents' : 'Present', present, const Color(0xFF22C55E)),
              const SizedBox(width: 8),
              _chip(isFr ? 'Retards' : 'Late', late, const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _chip(isFr ? 'Absents' : 'Absent', absent, const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 14),

          // Search
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: isFr ? 'Rechercher…' : 'Search…',
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF2F2F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
          ),

          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$count $label', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Employee Row ─────────────────────────────────────────────────────────────

class _EmployeeRow extends StatelessWidget {
  final Employee employee;
  final String status;
  final bool isDark, isFr;
  final Color Function(String) statusColor;
  final Future<void> Function(String, String) onMark;

  static const _gold = Color(0xFFC9A24D);

  const _EmployeeRow({
    required this.employee,
    required this.status,
    required this.isDark,
    required this.isFr,
    required this.statusColor,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final color = statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status != 'none'
              ? color.withOpacity(0.25)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  employee.nom.isNotEmpty ? employee.nom[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + contract badge
                  Row(
                    children: [
                      Text(
                        '${employee.prenom} ${employee.nom}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _contractBadge(employee.typeContrat),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Poste + département
                  Row(
                    children: [
                      const Icon(Icons.work_outline_rounded, size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          employee.poste,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('·', style: TextStyle(color: Colors.grey)),
                      ),
                      const Icon(Icons.corporate_fare_rounded, size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          employee.departement,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Status badge + action buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (status != 'none') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel(status, isFr),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                _ActionButtons(
                  empId: employee.id!,
                  currentStatus: status,
                  onMark: onMark,
                  statusColor: statusColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contractBadge(String type) {
    final label = type.length > 8 ? type.substring(0, 8) : type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _gold.withOpacity(0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(color: _gold, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  String _statusLabel(String status, bool isFr) {
    final labels = isFr
        ? {'present': 'Présent', 'late': 'Retard', 'absent': 'Absent', 'remote': 'Remote'}
        : {'present': 'Present', 'late': 'Late', 'absent': 'Absent', 'remote': 'Remote'};
    return labels[status] ?? status;
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final String empId, currentStatus;
  final Future<void> Function(String, String) onMark;
  final Color Function(String) statusColor;

  const _ActionButtons({
    required this.empId,
    required this.currentStatus,
    required this.onMark,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn('present', Icons.check_rounded),
        const SizedBox(width: 4),
        _btn('late', Icons.schedule_rounded),
        const SizedBox(width: 4),
        _btn('absent', Icons.close_rounded),
        const SizedBox(width: 4),
        _btn('remote', Icons.home_work_rounded),
      ],
    );
  }

  Widget _btn(String s, IconData icon) {
    final active = currentStatus == s;
    final c = statusColor(s);
    return InkWell(
      onTap: () => onMark(empId, s),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active ? c : c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: active ? Colors.white : c),
      ),
    );
  }
}
