import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import 'package:fs_hub/features/employees/services/employee_service.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import '../widgets/employee_history_bottom_sheet.dart';

class HrAttendanceHistoryPage extends StatefulWidget {
  const HrAttendanceHistoryPage({super.key});

  @override
  State<HrAttendanceHistoryPage> createState() => _HrAttendanceHistoryPageState();
}

class _HrAttendanceHistoryPageState extends State<HrAttendanceHistoryPage> {
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isOwnHistoryMode = false; // true when user can only see their own history
  String? _currentUserId;
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
      final canViewAll = await AuthService.hasPermission('view_employees');
      final user = await AuthService.getCurrentUser();
      _currentUserId = user?['id']?.toString();

      if (canViewAll) {
        // Admin/RH: load full employee directory
        final emps = await EmployeeService.getAllEmployees();
        if (mounted) {
          setState(() {
            _employees = emps;
            _filteredEmployees = emps;
            _isOwnHistoryMode = false;
            _isLoading = false;
          });
        }
      } else {
        // Regular employee: go straight to their own record
        if (mounted) {
          setState(() {
            _isOwnHistoryMode = true;
            _isLoading = false;
          });
          // Show their own attendance immediately after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentUserId != null) {
              _showOwnHistory();
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOwnHistory() {
    if (_currentUserId == null) return;
    // Create a minimal Employee stub using the session data for display
    AuthService.getCurrentUser().then((user) {
      if (user == null || !mounted) return;
      final stub = Employee(
        id: _currentUserId!,
        matricule: 'M-${_currentUserId!.substring(0, 4)}',
        nom: user['nom']?.toString() ?? '',
        prenom: user['prenom']?.toString() ?? '',
        email: user['email']?.toString() ?? '',
        poste: user['role']?.toString() ?? '',
        departement: 'N/A',
        dateEmbauche: DateTime.now(),
        dateNaissance: DateTime(1990, 1, 1),
        sexe: 'M',
        telephone: '0000',
        adresse: 'N/A',
        ville: 'N/A',
        typeContrat: 'N/A',
        statut: 'Actif',
        username: user['username']?.toString(),
      );
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EmployeeHistoryBottomSheet(employee: stub),
      );
    });
  }

  void _showEmployeeHistory(Employee employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmployeeHistoryBottomSheet(employee: employee),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    if (_isLoading) {
      return LuxuryScaffold(
        title: isFr ? 'Historique de Présence' : 'Attendance History',
        showBackButton: true,
        body: const Center(child: CircularProgressIndicator(color: _gold)),
      );
    }

    // Non-admin mode: show a simple "My Attendance" screen with a button to reopen the sheet
    if (_isOwnHistoryMode) {
      return LuxuryScaffold(
        title: isFr ? 'Mon Historique' : 'My Attendance',
        showBackButton: true,
        body: Container(
          color: bg,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 100),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: _gold, size: 56),
                ),
                const SizedBox(height: 24),
                Text(
                  isFr ? 'Mon Calendrier de Présence' : 'My Attendance Calendar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isFr ? 'Consultez votre historique de pointage mensuel.' : 'View your monthly check-in history.',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _showOwnHistory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    isFr ? 'Voir mon historique' : 'View my history',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Admin/RH mode: full employee directory
    return LuxuryScaffold(
      title: isFr ? 'Historique de Présence' : 'Attendance History',
      showBackButton: true,
      body: Container(
        color: bg,
        child: Column(
          children: [
            const SizedBox(height: 100),
            _SearchHeader(
              isFr: isFr,
              isDark: isDark,
              searchCtrl: _searchCtrl,
              totalEmployees: _employees.length,
            ),
            Expanded(
              child: _filteredEmployees.isEmpty
                  ? _emptyState(isFr)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (_, i) => _EmployeeHistoryRow(
                        employee: _filteredEmployees[i],
                        isDark: isDark,
                        isFr: isFr,
                        onTap: () => _showEmployeeHistory(_filteredEmployees[i]),
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
            isFr ? 'Aucun employé trouvé' : 'No employees found',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final bool isFr, isDark;
  final TextEditingController searchCtrl;
  final int totalEmployees;

  const _SearchHeader({
    required this.isFr,
    required this.isDark,
    required this.searchCtrl,
    required this.totalEmployees,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr ? 'Recherche d\'Employé' : 'Employee Search',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            isFr ? 'Cliquez sur un employé pour voir son calendrier.' : 'Click an employee to view their attendance calendar.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: isFr ? 'Rechercher par nom, poste...' : 'Search by name, position...',
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
}

class _EmployeeHistoryRow extends StatefulWidget {
  final Employee employee;
  final bool isDark, isFr;
  final VoidCallback onTap;

  const _EmployeeHistoryRow({
    required this.employee,
    required this.isDark,
    required this.isFr,
    required this.onTap,
  });

  @override
  State<_EmployeeHistoryRow> createState() => _EmployeeHistoryRowState();
}

class _EmployeeHistoryRowState extends State<_EmployeeHistoryRow> {
  bool _isHovered = false;
  static const _gold = Color(0xFFC9A24D);

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered ? _gold.withOpacity(0.05) : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered 
                ? _gold.withOpacity(0.4) 
                : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
            ),
            boxShadow: _isHovered ? [
              BoxShadow(
                color: _gold.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(_isHovered ? 1.0 : 0.9),
                  shape: BoxShape.circle,
                  boxShadow: _isHovered ? [
                    BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)
                  ] : [],
                ),
                child: Center(
                  child: Text(
                    widget.employee.nom.isNotEmpty ? widget.employee.nom[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.employee.prenom} ${widget.employee.nom}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.employee.poste} · ${widget.employee.departement}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isHovered ? _gold.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month_rounded, 
                  color: _isHovered ? _gold : Colors.grey.shade400, 
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded, 
                color: _isHovered ? _gold : Colors.grey.shade400, 
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
