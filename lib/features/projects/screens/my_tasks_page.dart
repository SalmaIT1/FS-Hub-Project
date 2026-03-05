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

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  List<Task> _tasks = [];
  List<Sprint> _activeSprints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await TaskService.getMyTasks();
      
      // Update tasks immediately so the user sees them
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }

      // Load active sprints in the background for the FAB
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

    return Scaffold(
      appBar: const LuxuryAppBar(
        title: 'Mes Tâches',
        subtitle: 'Pipeline personnel',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: _tasks.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) => _buildTaskCard(_tasks[index], isDark),
                    ),
            ),
      floatingActionButton: _activeSprints.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _showCreateTaskDialog,
        label: const Text('Nouvelle Tâche', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        backgroundColor: AppTheme.accentGold,
      ) : null,
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

  Widget _buildTaskCard(Task task, bool isDark) {
    Color statusColor;
    switch (task.statut) {
      case 'Done': statusColor = Colors.green; break;
      case 'Testing': statusColor = Colors.purple; break;
      case 'InProgress': statusColor = Colors.blue; break;
      case 'ToDo': statusColor = Colors.orange; break;
      default: statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(task.titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${task.projectNom} » ${task.sprintNom}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: _buildPriorityChip(task.priorite),
          ),
          if (task.description != null && task.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(task.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusBadge(task.statut, statusColor),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${task.heuresReelles}/${task.estimationHeures}h', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                TextButton(
                  onPressed: () => _updateStatus(task),
                  child: const Text('Mettre à jour', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'High': color = Colors.redAccent; break;
      case 'Medium': color = Colors.orangeAccent; break;
      default: color = Colors.blueAccent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(priority, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
