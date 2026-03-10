import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:fs_hub/shared/models/project_model.dart';
import 'package:fs_hub/shared/models/sprint_model.dart';
import '../services/sprint_service.dart';
import '../services/task_service.dart';
import 'package:fs_hub/shared/widgets/reporting/burndown_chart.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class SprintsListPage extends StatefulWidget {
  final Project project;

  const SprintsListPage({super.key, required this.project});

  @override
  State<SprintsListPage> createState() => _SprintsListPageState();
}

class _SprintsListPageState extends State<SprintsListPage> with SingleTickerProviderStateMixin {
  List<Sprint> _sprints = [];
  Map<int, List<dynamic>> _burndowns = {};
  bool _isLoading = true;
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadSprints();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadSprints() async {
    setState(() => _isLoading = true);
    try {
      final sprints = await SprintService.getSprintsByProject(widget.project.id!);
      
      final futures = sprints.map((s) => TaskService.getBurndownData(s.id!)).toList();
      final burndownResults = await Future.wait(futures);
      
      final Map<int, List<dynamic>> burndownMap = {};
      for (int i = 0; i < sprints.length; i++) {
        burndownMap[sprints[i].id!] = burndownResults[i];
      }

      if (mounted) {
        setState(() {
          _sprints = sprints;
          _burndowns = burndownMap;
          _isLoading = false;
        });
        _listController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sprints: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: LuxuryAppBar(
        title: '${settings.translate('sprints') ?? 'Sprints'}: ${widget.project.nom}',
        subtitle: settings.translate('sprints_subtitle') ?? 'Manage project iterations',
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
          onRefresh: _loadSprints,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
              : _sprints.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: _sprints.length,
                      itemBuilder: (context, index) {
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
                          child: _buildSprintCard(_sprints[index], isDark, settings),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: _buildFAB(isDark),
    );
  }

  Widget _buildSprintCard(Sprint sprint, bool isDark, SettingsController settings) {
    bool isCurrent = sprint.dateDebut != null && 
                    sprint.dateFin != null && 
                    DateTime.now().isAfter(sprint.dateDebut!) && 
                    DateTime.now().isBefore(sprint.dateFin!.add(const Duration(days: 1)));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent 
            ? AppTheme.accentGold.withOpacity(0.5) 
            : AppTheme.accentGold.withOpacity(0.15)
        ),
        boxShadow: [
          if (isCurrent)
            BoxShadow(
              color: AppTheme.accentGold.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sprint.nom,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(color: AppTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sprint.objectif != null && sprint.objectif!.isNotEmpty)
                  Text(
                    sprint.objectif!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoItem(Icons.calendar_today_rounded, '${_formatDate(sprint.dateDebut)} - ${_formatDate(sprint.dateFin)}'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.accentGold),
                      onPressed: () => _showAddEditDialog(sprint),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(sprint),
                    ),
                  ],
                ),
                if (_burndowns.containsKey(sprint.id) && _burndowns[sprint.id]!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                  ),
                  Row(
                    children: [
                      Icon(Icons.insights_rounded, size: 14, color: AppTheme.accentGold),
                      SizedBox(width: 6),
                      Text(settings.translate('burndown_tracker') ?? 'Suivi Burndown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentGold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BurndownChart(data: _burndowns[sprint.id]!, isDark: isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_run_rounded, size: 80, color: AppTheme.accentGold.withOpacity(0.2)),
          const SizedBox(height: 20),
          const Text('No Sprints Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Define your first sprint to start working', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFAB(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () => _showAddEditDialog(),
      label: const Text('New Sprint', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      backgroundColor: AppTheme.accentGold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  void _showAddEditDialog([Sprint? sprint]) {
    showDialog(
      context: context,
      builder: (context) => AddEditSprintDialog(
        projectId: widget.project.id!,
        sprint: sprint,
        onSave: _loadSprints,
      ),
    );
  }

  void _confirmDelete(Sprint sprint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sprint'),
        content: Text('Are you sure you want to delete "${sprint.nom}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await SprintService.deleteSprint(sprint.id!);
              if (result['success']) _loadSprints();
              if (mounted) {
                LuxuryStatusDialog.show(
                  context,
                  isSuccess: result['success'],
                  title: result['success'] ? 'Sprint Purged' : 'Registry Conflict',
                  message: result['message'] ?? 'The iteration cycle has been removed from the project timeline.',
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class AddEditSprintDialog extends StatefulWidget {
  final int projectId;
  final Sprint? sprint;
  final VoidCallback onSave;

  const AddEditSprintDialog({super.key, required this.projectId, this.sprint, required this.onSave});

  @override
  State<AddEditSprintDialog> createState() => _AddEditSprintDialogState();
}

class _AddEditSprintDialogState extends State<AddEditSprintDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _objController;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.sprint?.nom ?? '');
    _objController = TextEditingController(text: widget.sprint?.objectif ?? '');
    if (widget.sprint != null) {
      _dateDebut = widget.sprint!.dateDebut;
      _dateFin = widget.sprint!.dateFin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.sprint == null ? 'New Sprint' : 'Edit Sprint'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(labelText: 'Sprint Name (e.g. Sprint 1)'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _objController,
                decoration: const InputDecoration(labelText: 'Objective'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDatePicker('Start', _dateDebut, (d) => setState(() => _dateDebut = d))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDatePicker('End', _dateFin, (d) => setState(() => _dateFin = d))),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.white),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onSelect(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(date == null ? 'Select' : DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final sprint = Sprint(
      id: widget.sprint?.id,
      projectId: widget.projectId,
      nom: _nomController.text,
      objectif: _objController.text,
      dateDebut: _dateDebut,
      dateFin: _dateFin,
    );

    final result = widget.sprint == null 
        ? await SprintService.createSprint(sprint)
        : await SprintService.updateSprint(sprint);

    if (mounted) {
      if (result['success']) {
        widget.onSave();
        Navigator.pop(context);
        LuxuryStatusDialog.show(
          context,
          isSuccess: true,
          title: widget.sprint == null ? 'Sprint Synchronized' : 'Cycle Updated',
          message: result['message'] ?? 'The iteration parameters have been committed to the neural project map.',
        );
      } else {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'Initialization Fault',
          message: result['message'] ?? 'Unable to establish the requested iteration cycle.',
        );
      }
      setState(() => _isSaving = false);
    }
  }
}


