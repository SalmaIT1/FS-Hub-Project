import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:fs_hub/shared/models/project_model.dart';
import 'package:fs_hub/shared/models/sprint_model.dart';
import 'package:fs_hub/features/projects/services/sprint_service.dart';
import 'package:fs_hub/features/projects/services/project_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/features/projects/screens/sprints_list_page.dart' show AddEditSprintDialog;
import 'package:fs_hub/shared/models/project_member_model.dart';
import 'package:fs_hub/features/projects/services/task_service.dart';
import 'package:fs_hub/shared/widgets/reporting/burndown_chart.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class ProjectDetailPage extends StatefulWidget {
  final Project project;

  const ProjectDetailPage({super.key, required this.project});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> with SingleTickerProviderStateMixin {
  late Project _project;
  List<Sprint> _sprints = [];
  List<ProjectMember> _members = [];
  Map<int, List<dynamic>> _sprintBurndowns = {};
  int? _selectedBurndownSprintId;
  bool _isLoadingSprints = true;
  bool _isLoadingMembers = true;
  bool _isLoadingBurndowns = true;
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoadingSprints = true;
        _isLoadingMembers = true;
        _isLoadingBurndowns = true;
      });
    }
    
    try {
      final updatedProject = await ProjectService.getProjectById(_project.id!);
      if (updatedProject != null && mounted) {
        setState(() => _project = updatedProject);
      }
      
      // Load sprints
      final sprints = await SprintService.getSprintsByProject(_project.id!);
      
      // Load burndown data for each sprint
      final burndownFutures = sprints.map((s) => TaskService.getBurndownData(s.id!)).toList();
      final burndowns = await Future.wait(burndownFutures);
      
      final burndownMap = <int, List<dynamic>>{};
      for (int i = 0; i < sprints.length; i++) {
        burndownMap[sprints[i].id!] = burndowns[i];
      }

      // Load members
      final members = await ProjectService.getProjectMembers(_project.id!);

      if (mounted) {
        setState(() {
          _sprints = sprints;
          _members = members;
          _sprintBurndowns = burndownMap;
          _isLoadingSprints = false;
          _isLoadingMembers = false;
          _isLoadingBurndowns = false;
        });
        _listController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSprints = false;
          _isLoadingMembers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: LuxuryAppBar(
        title: _project.nom,
        subtitle: settings.translate('project_details') ?? 'Project details & insights',
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
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _buildProjectInfoCard(isDark),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Project Team',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddMemberDialog(),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppTheme.accentGold),
                        label: const Text('Add Member', style: TextStyle(color: AppTheme.accentGold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              _isLoadingMembers
                ? const SliverToBoxAdapter(child: Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppTheme.accentGold),
                  )))
                : _members.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptyTeamState())
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildMemberCard(_members[index], isDark),
                            childCount: _members.length,
                          ),
                        ),
                      ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Burndown Chart Section
              if (_sprints.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Sprint Velocity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Icon(Icons.insights_rounded, size: 18, color: AppTheme.accentGold.withOpacity(0.5)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Tracking ideal vs. actual remaining effort (Burndown)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 24),
                        _isLoadingBurndowns 
                          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)))
                          : _buildBurndownSection(isDark),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Agile Sprints',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_project.statut == 'En cours')
                        TextButton.icon(
                          onPressed: () => _showAddEditSprintDialog(),
                          icon: const Icon(Icons.add_rounded, size: 18, color: AppTheme.accentGold),
                          label: const Text('New Sprint', style: TextStyle(color: AppTheme.accentGold)),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (_project.statut == 'En cours') ...[
                _isLoadingSprints 
                  ? const SliverToBoxAdapter(child: Center(child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: AppTheme.accentGold),
                    )))
                  : _sprints.isEmpty
                      ? _buildEmptySprintsState()
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: _listController,
                                  curve: Interval((index / 10).clamp(0.0, 1.0), 1.0, curve: Curves.easeOutCubic),
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
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: _buildSprintCard(_sprints[index], isDark),
                                ),
                              );
                            },
                            childCount: _sprints.length,
                          ),
                        ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.lock_rounded, size: 40, color: Colors.grey.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          const Text(
                            'Sprints become available when project is "En cours"',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge(_project.statut, _getStatusColor(_project.statut)),
              _buildBadge(_project.priorite, _getPriorityColor(_project.priorite)),
            ],
          ),
          const SizedBox(height: 20),
          if (_project.clientName != null) ...[
            Text('CLIENT', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppTheme.accentGold.withOpacity(0.7), fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_project.clientName!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Colors.grey)),
          ],
          if (_project.description != null && _project.description!.isNotEmpty) ...[
            Text('DESCRIPTION', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey.withOpacity(0.7), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_project.description!, style: const TextStyle(fontSize: 14, height: 1.6)),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              _buildMetricItem('Budget', NumberFormat.currency(symbol: '€').format(_project.budget)),
              const Spacer(),
              _buildMetricItem('Estimated', NumberFormat.currency(symbol: '€').format(_project.coutEstime)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMetricItem('Start Date', _formatDate(_project.dateDebut)),
              const Spacer(),
              _buildMetricItem('Finish Due', _formatDate(_project.dateFinPrevue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentGold)),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Planifié': return Colors.blue;
      case 'En cours': return Colors.orange;
      case 'Terminé': return Colors.green;
      case 'En retard': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String p) {
    switch (p) {
      case 'Faible': return Colors.green;
      case 'Moyenne': return Colors.blue;
      case 'Haute': return Colors.orange;
      case 'Critique': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildSprintCard(Sprint sprint, bool isDark) {
    bool isCurrent = sprint.dateDebut != null && 
                    sprint.dateFin != null && 
                    DateTime.now().isAfter(sprint.dateDebut!) && 
                    DateTime.now().isBefore(sprint.dateFin!.add(const Duration(days: 1)));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isCurrent ? AppTheme.accentGold : Colors.grey.withOpacity(0.1)),
        boxShadow: [
          if (isCurrent) BoxShadow(color: AppTheme.accentGold.withOpacity(0.1), blurRadius: 10),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(sprint.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sprint.objectif != null) Text(sprint.objectif!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                const SizedBox(width: 6),
                Text('${_formatDate(sprint.dateDebut)} - ${_formatDate(sprint.dateFin)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  const Text('• ACTIVE', style: TextStyle(fontSize: 10, color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
                ]
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.accentGold), onPressed: () => _showAddEditSprintDialog(sprint)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent), onPressed: () => _confirmDeleteSprint(sprint)),
          ],
        ),
      ),
    );
  }

  Widget _buildSprintSummary(List<dynamic> data, bool isDark) {
    if (data.isEmpty) return const SizedBox();

    // Find the current day (last point with actual != null)
    Map<String, dynamic>? currentDay;
    for (var i = data.length - 1; i >= 0; i--) {
      if (data[i]['actual'] != null) {
        currentDay = data[i];
        break;
      }
    }

    if (currentDay == null) return const SizedBox();

    final double ideal = double.parse(currentDay['ideal'].toString());
    final double actual = double.parse(currentDay['actual'].toString());
    final double diff = ideal - actual;
    final bool isAhead = diff >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _buildSummaryCard(
            'Statut',
            isAhead ? 'En avance' : 'En retard',
            isAhead ? Colors.green : Colors.redAccent,
            isAhead ? Icons.trending_down_rounded : Icons.trending_up_rounded,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Variance',
            '${diff.abs().toStringAsFixed(1)}h',
            AppTheme.accentGold,
            Icons.speed_rounded,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Progression',
            '${((1 - (actual / double.parse(data[0]['ideal'].toString()))) * 100).clamp(0, 100).toStringAsFixed(0)}%',
            Colors.blueAccent,
            Icons.ads_click_rounded,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(ProjectMember member, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentGold.withOpacity(0.1),
          child: Text(member.prenom[0] + member.nom[0], style: const TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${member.role} • ${member.poste ?? 'Staff'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_rounded, size: 20, color: Colors.redAccent),
          onPressed: () => _confirmRemoveMember(member),
        ),
      ),
    );
  }

  Widget _buildEmptyTeamState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 40, color: Colors.grey.withOpacity(0.2)),
            const SizedBox(height: 12),
            const Text('No team members assigned', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMemberDialog(
        projectId: _project.id!,
        onSave: _loadData,
      ),
    );
  }

  void _confirmRemoveMember(ProjectMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Team'),
        content: Text('Remove ${member.displayName} from this project?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await ProjectService.removeProjectMember(_project.id!, member.employeeId);
              if (res['success']) {
                _loadData();
                LuxuryStatusDialog.show(
                  context,
                  isSuccess: true,
                  title: 'Personnel Reassigned',
                  message: res['message'],
                );
              } else {
                LuxuryStatusDialog.show(
                  context,
                  isSuccess: false,
                  title: 'Reassignment Fault',
                  message: res['message'],
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySprintsState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_run_outlined, size: 60, color: AppTheme.accentGold.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('No sprints recorded yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _showAddEditSprintDialog([Sprint? sprint]) {
    showDialog(context: context, builder: (context) => AddEditSprintDialog(projectId: _project.id!, sprint: sprint, onSave: _loadData));
  }

  Widget _buildBurndownSection(bool isDark) {
    if (_sprints.isEmpty) return const SizedBox();

    Sprint sprintToShow;
    if (_selectedBurndownSprintId != null) {
      sprintToShow = _sprints.firstWhere((s) => s.id == _selectedBurndownSprintId, orElse: () => _getActiveSprint() ?? _sprints.first);
    } else {
      sprintToShow = _getActiveSprint() ?? _sprints.first;
    }
    
    final burndownData = _sprintBurndowns[sprintToShow.id!] ?? [];
    final activeSprint = _getActiveSprint();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                ),
                child: Text(
                  activeSprint?.id == sprintToShow.id ? 'Active: ${sprintToShow.nom}' : 'Sprint: ${sprintToShow.nom}',
                  style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            if (_sprints.length > 1)
              _buildSprintDropdown(isDark, sprintToShow),
          ],
        ),
        const SizedBox(height: 16),
        if (burndownData.isEmpty)
           const SizedBox(
             height: 150,
             child: Center(child: Text('No data found for this sprint', style: TextStyle(color: Colors.grey))),
           )
        else ...[
          _buildSprintSummary(burndownData, isDark),
          BurndownChart(data: burndownData, isDark: isDark),
        ],
      ],
    );
  }

  Sprint? _getActiveSprint() {
    final now = DateTime.now();
    try {
      return _sprints.firstWhere((s) => 
        s.dateDebut != null && s.dateFin != null &&
        now.isAfter(s.dateDebut!) && 
        now.isBefore(s.dateFin!.add(const Duration(days: 1)))
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildSprintDropdown(bool isDark, Sprint current) {
    return PopupMenuButton<Sprint>(
      icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.accentGold),
      onSelected: (s) {
        setState(() {
          _selectedBurndownSprintId = s.id;
        });
      },
      itemBuilder: (context) => _sprints.map((s) => PopupMenuItem(
        value: s,
        child: Text(s.nom, style: TextStyle(fontWeight: s.id == current.id ? FontWeight.bold : FontWeight.normal)),
      )).toList(),
    );
  }

  void _confirmDeleteSprint(Sprint sprint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sprint'),
        content: Text('Remove "${sprint.nom}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await SprintService.deleteSprint(sprint.id!);
              if (mounted) {
                if (res['success']) {
                  _loadData();
                  LuxuryStatusDialog.show(
                    context,
                    isSuccess: true,
                    title: 'Sprint Purged',
                    message: 'Chronological segment has been removed from the timeline.',
                  );
                } else {
                  LuxuryStatusDialog.show(
                    context,
                    isSuccess: false,
                    title: 'Purge Failure',
                    message: res['message'] ?? 'Critical dependency prevented chronological removal.',
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class AddMemberDialog extends StatefulWidget {
  final int projectId;
  final VoidCallback onSave;

  const AddMemberDialog({super.key, required this.projectId, required this.onSave});

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  List<ProjectMember> _availableEmployees = [];
  bool _isLoading = true;
  String? _selectedEmployeeId;
  String _role = 'Membre';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailable();
  }

  Future<void> _loadAvailable() async {
    final employees = await ProjectService.getAvailableEmployees();
    if (mounted) {
      // Filter out those already in THE CURRENT team just in case
      setState(() {
        _availableEmployees = employees;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Add Team Member'),
        content: _isLoading 
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)))
          : _availableEmployees.isEmpty
            ? const SizedBox(height: 100, child: Center(child: Text('No available employees found', style: TextStyle(color: Colors.grey))))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Showing employees not currently assigned to any active project.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedEmployeeId,
                    decoration: const InputDecoration(labelText: 'Select Employee'),
                    items: _availableEmployees.map((e) => DropdownMenuItem(
                      value: e.employeeId,
                      child: Text('${e.prenom} ${e.nom} (${e.poste ?? 'RH'})'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedEmployeeId = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role in Project'),
                    onChanged: (v) => _role = v,
                  ),
                ],
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: (_selectedEmployeeId == null || _isSaving) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final res = await ProjectService.addProjectMember(widget.projectId, _selectedEmployeeId!, _role);
    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success']) {
        widget.onSave();
        Navigator.pop(context);
        LuxuryStatusDialog.show(
          context,
          isSuccess: true,
          title: 'Unit Deployed',
          message: 'Member has been successfully integrated into the project squad.',
        );
      } else {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Deployment Failure',
          message: res['message'] ?? 'Unit mismatch detected by core validator.',
        );
      }
    }
  }
}
