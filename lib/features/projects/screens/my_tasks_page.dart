import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/shared/models/task_model.dart';
import 'package:fs_hub/features/projects/services/task_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/shared/models/sprint_model.dart';
import 'package:fs_hub/features/projects/services/sprint_service.dart';
import 'package:fs_hub/features/projects/services/project_service.dart';
import 'package:fs_hub/shared/models/project_model.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> with TickerProviderStateMixin {
  List<Task> _tasks = [];
  List<Sprint> _activeSprints = [];
  bool _isLoading = true;
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      final isAdmin = user?['role'] == 'Admin';
      
      final tasks = isAdmin ? await TaskService.getAllTasks() : await TaskService.getMyTasks();
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
        _listController.forward(from: 0);
      }

      _loadActiveSprints();
    } catch (e) {
      print('Error loading tasks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActiveSprints() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) return;

      List<Sprint> mySprints = [];
      final projects = await ProjectService.getAllProjects();
      
      for (var p in projects) {
        try {
          final pSprints = await SprintService.getSprintsByProject(p.id!);
          final now = DateTime.now();
          final active = pSprints.where((s) => 
            s.dateDebut != null && s.dateFin != null &&
            now.isAfter(s.dateDebut!) && 
            now.isBefore(s.dateFin!.add(const Duration(days: 1)))
          ).toList();
          mySprints.addAll(active);
        } catch (e) {
          print('Error loading sprints for project ${p.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _activeSprints = mySprints;
        });
      }
    } catch (e) {
      print('Error loading active sprints: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsController>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: LuxuryAppBar(
        title: settings.translate('mes_taches'),
        subtitle: settings.translate('pipeline_personnel'),
        isPremium: true,
        showBackButton: false,
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
          onRefresh: _loadTasks,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Summary Card
              SliverToBoxAdapter(
                child: _buildSummaryCard(isDark, settings),
              ),
              
              // Task List
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: ExcludeSemantics(child: CircularProgressIndicator(color: AppTheme.accentGold))),
                )
              else if (_tasks.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(isDark))
              else
                SliverPadding(
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
                          child: _buildTaskCard(_tasks[index], isDark, settings),
                        );
                      },
                      childCount: _tasks.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _activeSprints.isNotEmpty ? _buildFAB(settings) : null,
    );
  }

  Widget _buildFAB(SettingsController settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 90),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [AppTheme.accentGold, Color(0xFF8B6914)]),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'fab_tasks',
        onPressed: _showCreateTaskDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: Text(settings.translate('new_task'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, SettingsController settings) {
    final todo = _tasks.where((t) => t.statut == 'ToDo').length;
    final inProgress = _tasks.where((t) => t.statut == 'InProgress').length;
    final done = _tasks.where((t) => t.statut == 'Done').length;

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
          _buildStatItem(settings.translate('todo'), todo.toString(), Icons.pending_actions_rounded),
          Container(width: 1, height: 40, color: AppTheme.accentGold.withOpacity(0.1)),
          _buildStatItem(settings.translate('in_progress_short'), inProgress.toString(), Icons.play_circle_outline_rounded),
          Container(width: 1, height: 40, color: AppTheme.accentGold.withOpacity(0.1)),
          _buildStatItem(settings.translate('done'), done.toString(), Icons.check_circle_outline_rounded),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rtl_outlined, size: 60, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Aucune tâche assignée',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, bool isDark, SettingsController settings) {
    Color statusColor;
    switch (task.statut) {
      case 'Done': statusColor = const Color(0xFF4CAF50); break;
      case 'Testing': statusColor = const Color(0xFF9C27B0); break;
      case 'InProgress': statusColor = const Color(0xFF2196F3); break;
      case 'ToDo': statusColor = const Color(0xFFFF9800); break;
      default: statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Project/Sprint info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
              ),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined, size: 14, color: AppTheme.accentGold.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${task.projectNom} » ${task.sprintNom}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildPriorityChip(task.priorite, settings),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.titre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (task.heuresReelles > task.estimationHeures && task.statut != 'Done')
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            settings.translate('delayed').toUpperCase(),
                            style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                    ],
                  ),
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.transparent),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildStatusBadge(task.statut, statusColor, settings),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 12, color: AppTheme.accentGold.withOpacity(0.8)),
                            const SizedBox(width: 4),
                            Text(
                              '${task.heuresReelles}/${task.estimationHeures}h',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _updateStatus(task),
                    style: TextButton.styleFrom(
                      overlayColor: AppTheme.accentGold.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      settings.translate('update').toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority, SettingsController settings) {
    Color color;
    switch (priority) {
      case 'High': color = const Color(0xFFFF5252); break;
      case 'Medium': color = const Color(0xFFFFAB40); break;
      default: color = const Color(0xFF448AFF);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        settings.translate(priority.toLowerCase()).toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color, SettingsController settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            settings.translate(status.toLowerCase()),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  void _updateStatus(Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Changer le statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ...['ToDo', 'InProgress', 'Testing', 'Done'].map((s) => ListTile(
              leading: Icon(Icons.circle, color: s == task.statut ? AppTheme.accentGold : Colors.grey, size: 12),
              title: Text(s),
              onTap: () async {
                Navigator.pop(context);
                final updated = Task(
                  id: task.id,
                  titre: task.titre,
                  description: task.description,
                  sprintId: task.sprintId,
                  employeeId: task.employeeId,
                  statut: s,
                  priorite: task.priorite,
                  estimationHeures: task.estimationHeures,
                  heuresReelles: task.heuresReelles,
                );
                try {
                  final res = await TaskService.updateTask(updated);
                  if (mounted) {
                    if (res['success'] == true) {
                      LuxuryStatusDialog.show(
                        context,
                        isSuccess: true,
                        title: 'Status Updated',
                        message: 'Task "$s" status finalized successfully.',
                      );
                      _loadTasks();
                    } else {
                      LuxuryStatusDialog.show(
                        context,
                        isSuccess: false,
                        title: 'Update Failed',
                        message: res['error'] ?? 'Neural link interference detected.',
                      );
                    }
                  }
                } catch (e) {
                   if (mounted) {
                    LuxuryStatusDialog.show(
                      context,
                      isSuccess: false,
                      title: 'Critical Error',
                      message: e.toString(),
                    );
                  }
                }
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(
        activeSprints: _activeSprints,
        onSave: _loadTasks,
      ),
    );
  }
}

class CreateTaskDialog extends StatefulWidget {
  final List<Sprint> activeSprints;
  final VoidCallback onSave;

  const CreateTaskDialog({super.key, required this.activeSprints, required this.onSave});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _estController = TextEditingController(text: '1');
  int? _selectedSprintId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.activeSprints.isNotEmpty) {
      _selectedSprintId = widget.activeSprints.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151515).withOpacity(0.95) : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_task_rounded, color: AppTheme.accentGold, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'NOUVELLE TÂCHE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: AppTheme.accentGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    _buildLabel('SPRINT ACTIF'),
                    _buildDropdownField(isDark),
                    
                    const SizedBox(height: 20),
                    
                    _buildLabel('DÉSIGNATION'),
                    _buildTextField(_titleController, 'Titre de la mission', isDark, Icons.title_rounded, (v) => v?.isEmpty ?? true ? 'Requis' : null),
                    
                    const SizedBox(height: 20),
                    
                    _buildLabel('DESCRIPTION'),
                    _buildTextField(_descController, 'Détails tactiques...', isDark, Icons.description_rounded, null, maxLines: 3),
                    
                    const SizedBox(height: 20),
                    
                    _buildLabel('EFFORT ESTIMÉ (HEURES)'),
                    _buildTextField(_estController, '1', isDark, Icons.timer_rounded, (v) => int.tryParse(v ?? '') == null ? 'Nombre requis' : null, keyboardType: TextInputType.number),
                    
                    const SizedBox(height: 32),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              'ANNULER',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isSaving ? null : _save,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.accentGold, Color(0xFF8B6914)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentGold.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isSaving 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text(
                                      'DÉPLOYER',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDropdownField(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          value: _selectedSprintId,
          items: widget.activeSprints.map((s) => DropdownMenuItem(
            value: s.id,
            child: Text(s.nom, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) => setState(() => _selectedSprintId = v),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isDark, IconData icon, String? Function(String?)? validator, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
        prefixIcon: Icon(icon, color: AppTheme.accentGold.withOpacity(0.5), size: 18),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = await AuthService.getCurrentUser();
      final task = Task(
        sprintId: _selectedSprintId!,
        employeeId: user?['id']?.toString(),
        titre: _titleController.text,
        description: _descController.text,
        estimationHeures: int.parse(_estController.text),
        statut: 'ToDo',
        priorite: 'Medium',
      );

      final res = await TaskService.createTask(task);
      if (mounted) {
        if (res['success'] == true) {
          LuxuryStatusDialog.show(
            context,
            isSuccess: true,
            title: 'Task Orchestrated',
            message: 'Your new task has been registered into the pipeline.',
          );
          widget.onSave();
          Navigator.pop(context);
        } else {
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Creation Failed',
            message: res['error'] ?? 'Execution error in neural processor.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'System Error',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
