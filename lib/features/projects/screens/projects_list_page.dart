import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../shared/models/project_model.dart';
import '../../clients/models/client_model.dart';
import '../services/project_service.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/settings_controller.dart';
import '../../../core/routes/app_routes.dart';

class ProjectsListPage extends StatefulWidget {
  const ProjectsListPage({super.key});

  @override
  State<ProjectsListPage> createState() => _ProjectsListPageState();
}

class _ProjectsListPageState extends State<ProjectsListPage> with SingleTickerProviderStateMixin {
  List<Project> _projects = [];
  bool _isLoading = true;
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadProjects();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final projects = await ProjectService.getAllProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoading = false;
        });
        _listController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading projects: $e')),
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
        title: settings.translate('projects') ?? 'Projects',
        subtitle: settings.translate('projects_subtitle') ?? 'Manage your ongoing initiatives',
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
          onRefresh: _loadProjects,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
              : _projects.isEmpty
                  ? _buildEmptyState(isDark, settings)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: _projects.length,
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
                          child: _buildProjectCard(_projects[index], isDark),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: _buildFAB(isDark),
    );
  }

  Widget _buildProjectCard(Project project, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.15)),
        boxShadow: [
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
          child: InkWell(
            onTap: () => Navigator.pushNamed(
              context, 
              AppRoutes.projectDetail,
              arguments: {'project': project},
            ),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.nom,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (project.clientName != null)
                            Text(
                              project.clientName!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.accentGold.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(project.statut),
                  ],
                ),
                const SizedBox(height: 16),
                if (project.description != null && project.description!.isNotEmpty)
                  Text(
                    project.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoItem(Icons.calendar_today_rounded, _formatDate(project.dateDebut)),
                    const SizedBox(width: 16),
                    _buildInfoItem(Icons.priority_high_rounded, project.priorite),
                    const Spacer(),
                    Text(
                      '${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(project.budget)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (project.statut == 'En cours')
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context, 
                          AppRoutes.sprints,
                          arguments: {'project': project},
                        ),
                        icon: const Icon(Icons.directions_run_rounded, size: 18),
                        label: const Text('Manage Sprints', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold.withOpacity(0.15),
                          foregroundColor: AppTheme.accentGold,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.accentGold, width: 0.5),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _showAddEditDialog(project),
                          icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.accentGold),
                          label: const Text('Edit', style: TextStyle(color: AppTheme.accentGold)),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _confirmDelete(project),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildDeadlineAlert(project, isDark),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDeadlineAlert(Project project, bool isDark) {
    if (project.dateFinPrevue == null || project.statut == 'Terminé') {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(project.dateFinPrevue!.year, project.dateFinPrevue!.month, project.dateFinPrevue!.day);
    final daysRemaining = dueDate.difference(today).inDays;

    if (daysRemaining > 3) return const SizedBox.shrink();

    final isOverdue = daysRemaining < 0;
    final color = isOverdue ? Colors.redAccent : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_filled_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOverdue 
                ? 'PROJET DÉPASSÉ (${daysRemaining.abs()}j de retard)'
                : 'PROJET ÉCHÉANCE PROCHE (${daysRemaining == 0 ? "Aujourd'hui" : "dans $daysRemaining jours"})',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Planifié': color = Colors.blue; break;
      case 'En cours': color = Colors.orange; break;
      case 'Terminé': color = Colors.green; break;
      case 'En retard': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildEmptyState(bool isDark, SettingsController settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_rounded, size: 80, color: AppTheme.accentGold.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            settings.translate('no_projects') ?? 'No Projects Found',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text('Start by adding your first project', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFAB(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      // Glass effect for FAB
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        label: const Text('New Project', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        backgroundColor: AppTheme.accentGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  void _showAddEditDialog([Project? project]) {
    showDialog(
      context: context,
      builder: (context) => AddEditProjectDialog(
        project: project,
        onSave: _loadProjects,
      ),
    );
  }

  void _confirmDelete(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.nom}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ProjectService.deleteProject(project.id!);
              if (result['success']) {
                _loadProjects();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'])),
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

class AddEditProjectDialog extends StatefulWidget {
  final Project? project;
  final VoidCallback onSave;

  const AddEditProjectDialog({super.key, this.project, required this.onSave});

  @override
  State<AddEditProjectDialog> createState() => _AddEditProjectDialogState();
}

class _AddEditProjectDialogState extends State<AddEditProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _descController;
  late TextEditingController _budgetController;
  late TextEditingController _coutController;
  
  int? _selectedClientId;
  List<Client> _clients = [];
  String _selectedPriorite = 'Moyenne';
  String _selectedStatut = 'Planifié';
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.project?.nom ?? '');
    _descController = TextEditingController(text: widget.project?.description ?? '');
    _budgetController = TextEditingController(text: widget.project?.budget.toString() ?? '0.0');
    _coutController = TextEditingController(text: widget.project?.coutEstime.toString() ?? '0.0');
    
    if (widget.project != null) {
      _selectedClientId = widget.project!.clientId;
      _selectedPriorite = widget.project!.priorite;
      _selectedStatut = widget.project!.statut;
      _dateDebut = widget.project!.dateDebut;
      _dateFin = widget.project!.dateFinPrevue;
    }
    _loadClients();
  }

  Future<void> _loadClients() async {
    final clients = await ProjectService.getAvailableClients();
    if (mounted) setState(() => _clients = clients);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(widget.project == null ? 'New Project' : 'Edit Project'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(labelText: 'Project Name'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _selectedClientId,
                    decoration: const InputDecoration(labelText: 'Client'),
                    items: _clients.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.displayName),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedClientId = v),
                    validator: (v) => v == null ? 'Select a client' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _budgetController,
                          decoration: const InputDecoration(labelText: 'Budget (€)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _coutController,
                          decoration: const InputDecoration(labelText: 'Estimated Cost (€)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPriorite,
                          decoration: const InputDecoration(labelText: 'Priority'),
                          items: ['Faible', 'Moyenne', 'Haute', 'Critique'].map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedPriorite = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatut,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: ['Planifié', 'En cours', 'Terminé', 'En retard'].map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedStatut = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker('Start Date', _dateDebut, (d) => setState(() => _dateDebut = d)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDatePicker('End Date', _dateFin, (d) => setState(() => _dateFin = d)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
        ],
      ),
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
        child: Text(date == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    final project = Project(
      id: widget.project?.id,
      nom: _nomController.text,
      description: _descController.text,
      clientId: _selectedClientId,
      budget: double.tryParse(_budgetController.text) ?? 0.0,
      coutEstime: double.tryParse(_coutController.text) ?? 0.0,
      dateDebut: _dateDebut,
      dateFinPrevue: _dateFin,
      priorite: _selectedPriorite,
      statut: _selectedStatut,
    );

    final result = widget.project == null 
        ? await ProjectService.createProject(project)
        : await ProjectService.updateProject(project);

    if (mounted) {
      setState(() => _isSaving = false);
      if (result['success']) {
        widget.onSave();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }
}
