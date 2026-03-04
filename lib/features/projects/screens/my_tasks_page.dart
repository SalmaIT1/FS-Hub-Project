import 'package:flutter/material.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/shared/models/task_model.dart';
import 'package:fs_hub/features/projects/services/task_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/shared/models/sprint_model.dart';
import 'package:fs_hub/features/projects/services/sprint_service.dart';
import 'package:fs_hub/features/projects/services/project_service.dart';
import 'package:fs_hub/shared/models/project_model.dart';

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
                await TaskService.updateTask(updated);
                _loadTasks();
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
    return AlertDialog(
      title: const Text('Nouvelle Tâche'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedSprintId,
                decoration: const InputDecoration(labelText: 'Sprint'),
                items: widget.activeSprints.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.nom),
                )).toList(),
                onChanged: (v) => setState(() => _selectedSprintId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titre de la tâche'),
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estController,
                decoration: const InputDecoration(labelText: 'Estimation (heures)'),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v ?? '') == null ? 'Nombre requis' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.white),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer'),
        ),
      ],
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
          widget.onSave();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Erreur lors de la création')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
