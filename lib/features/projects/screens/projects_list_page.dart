import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/shared/models/project_model.dart';
import '../../clients/models/client_model.dart';
import '../services/project_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';
import 'package:fs_hub/shared/widgets/permission_guard.dart';

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
                          child: _buildProjectCard(_projects[index], isDark, settings),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: _buildFAB(isDark, settings),
    );
  }

  Widget _buildProjectCard(Project project, bool isDark, SettingsController settings) {
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
                      NumberFormat.currency(symbol: 'DT', decimalDigits: 3).format(project.budget),
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
                        label: Text(settings.translate('manage_sprints') ?? 'Manage Sprints', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    PermissionGuard(
                      permission: 'projects.manage',
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _showAddEditDialog(project),
                            icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.accentGold),
                            label: Text(settings.translate('edit') ?? 'Edit', style: const TextStyle(color: AppTheme.accentGold)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _confirmDelete(project),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            label: Text(settings.translate('delete') ?? 'Delete', style: const TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
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
    if (project.dateFinPrevue == null || project.statut == 'Termine' || project.statut == 'Terminé') {
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
      case 'Planifie': case 'Planifié': color = Colors.blue; break;
      case 'En cours': color = Colors.orange; break;
      case 'Termine': case 'Terminé': color = Colors.green; break;
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

  Widget _buildFAB(bool isDark, SettingsController settings) {
    return PermissionGuard(
      permission: 'projects.create',
      child: Container(
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
          label: Text(settings.translate('new_project') ?? 'New Project', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          backgroundColor: AppTheme.accentGold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
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
    final settings = context.read<SettingsController>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.translate('delete_project') ?? 'Delete Project'),
        content: Text("${settings.translate('confirm_delete_project') ?? 'Are you sure you want to delete this project?'} ${project.nom}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(settings.translate('cancel') ?? 'Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ProjectService.deleteProject(project.id!);
              if (result['success']) {
                _loadProjects();
              }
              if (mounted) {
                LuxuryStatusDialog.show(
                  context,
                  isSuccess: result['success'],
                  title: result['success'] ? settings.translate('success') ?? 'Success' : settings.translate('error') ?? 'Error',
                  message: result['message'],
                );
              }
            },
            child: Text(settings.translate('delete') ?? 'Delete', style: const TextStyle(color: Colors.red)),
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
  String _selectedStatut = 'Planifie';
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _isSaving = false;

  // Contract upload state
  Uint8List? _contractBytes;
  String? _contractFilename;
  bool _isUploadingContract = false;
  bool _projectHasContract = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.project?.nom ?? '');
    _descController = TextEditingController(text: widget.project?.description ?? '');
    _budgetController = TextEditingController(text: widget.project?.budget.toString() ?? '0.0');
    _coutController = TextEditingController(text: widget.project?.coutEstime.toString() ?? '0.0');
    
    if (widget.project != null) {
      _selectedClientId = widget.project!.clientId;
      
      // Normalize values to match dropdown items exactly (avoiding accent mismatches)
      final status = widget.project!.statut;
      if (status == 'Planifié') {
        _selectedStatut = 'Planifie';
      } else if (status == 'Terminé') {
        _selectedStatut = 'Termine';
      } else {
        _selectedStatut = status;
      }

      _selectedPriorite = widget.project!.priorite;
      _dateDebut = widget.project!.dateDebut;
      _dateFin = widget.project!.dateFinPrevue;
      _projectHasContract = widget.project!.hasContract;
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
    final settings = context.watch<SettingsController>();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500),
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.accentGold, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            widget.project == null 
                                ? settings.translate('new_project') ?? 'NEW PROJECT' 
                                : settings.translate('edit') ?? 'EDIT PROJECT',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: AppTheme.accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      
                      _buildLabel(settings.translate('project_name') ?? 'PROJECT IDENTITY'),
                      _buildTextField(_nomController, settings.translate('project_name') ?? 'Name of the initiative', isDark, Icons.business_center_rounded, (v) => v?.isEmpty ?? true ? settings.translate('required') ?? 'Required' : null),
                      
                      const SizedBox(height: 16),
                      
                      _buildLabel(settings.translate('clients') ?? 'CLIENT PORTFOLIO'),
                      _buildDropdownField<int>(
                        value: _clients.any((c) => c.id == _selectedClientId) ? _selectedClientId : null,
                        hint: 'Sélectionner un client',
                        isDark: isDark,
                        icon: Icons.person_search_rounded,
                        items: _clients.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.displayName, style: const TextStyle(fontSize: 14)),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedClientId = v),
                        validator: (v) => v == null ? 'Requis' : null,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildLabel('OBJECTIFS TACTIQUES'),
                      _buildTextField(_descController, 'Détails du projet...', isDark, Icons.description_rounded, null, maxLines: 2),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('ALLOCATION (DT)'),
                                _buildTextField(_budgetController, '0.00', isDark, Icons.account_balance_rounded, null, keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('COÛT PRÉVU (DT)'),
                                _buildTextField(_coutController, '0.00', isDark, Icons.analytics_rounded, null, keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Contract Upload Section ────────────────────────
                      if (widget.project != null) ...[
                        _buildLabel('CONTRAT D\'ENGAGEMENT CLIENT'),
                        _buildContractUploadSection(isDark),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('PRIORITÉ'),
                                _buildDropdownField<String>(
                                  value: ['Faible', 'Moyenne', 'Haute', 'Critique'].contains(_selectedPriorite) ? _selectedPriorite : 'Moyenne',
                                  hint: 'Priorité',
                                  isDark: isDark,
                                  icon: Icons.priority_high_rounded,
                                  items: [
                                    {'value': 'Faible', 'label': 'Faible'},
                                    {'value': 'Moyenne', 'label': 'Moyenne'},
                                    {'value': 'Haute', 'label': 'Haute'},
                                    {'value': 'Critique', 'label': 'Critique'}
                                  ].map<DropdownMenuItem<String>>((p) => DropdownMenuItem<String>(
                                    value: p['value']!,
                                    child: Text(p['label']!, style: const TextStyle(fontSize: 14)),
                                  )).toList(),
                                  onChanged: (v) => setState(() => _selectedPriorite = v!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('STATUT'),
                                _buildDropdownField<String>(
                                  value: ['Planifie', 'En cours', 'Termine', 'En retard'].contains(_selectedStatut) ? _selectedStatut : 'Planifie',
                                  hint: 'Statut',
                                  isDark: isDark,
                                  icon: Icons.flag_rounded,
                                  items: [
                                    {'value': 'Planifie', 'label': 'Planifié'},
                                    // 'En cours' only visible if a contract exists
                                    if (widget.project != null && (_projectHasContract || _contractBytes != null))
                                      {'value': 'En cours', 'label': 'En cours ✓'},
                                    {'value': 'Termine', 'label': 'Terminé'},
                                    {'value': 'En retard', 'label': 'En retard'}
                                  ].map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                                    value: s['value']!,
                                    child: Text(s['label']!, style: const TextStyle(fontSize: 14)),
                                  )).toList(),
                                  onChanged: (v) => setState(() => _selectedStatut = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('DÉPLOIEMENT'),
                                _buildDatePicker('Date début', _dateDebut, isDark, (d) => setState(() => _dateDebut = d)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('ÉCHÉANCE'),
                                _buildDatePicker('Date fin', _dateFin, isDark, (d) => setState(() => _dateFin = d)),
                              ],
                            ),
                          ),
                        ],
                      ),

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
                                settings.translate('cancel') ?? 'CANCEL',
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
                                    : Text(
                                        widget.project == null 
                                            ? settings.translate('save') ?? 'INITIALIZE' 
                                            : settings.translate('update') ?? 'UPDATE',
                                        style: const TextStyle(
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
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.grey,
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
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
        prefixIcon: Icon(icon, color: AppTheme.accentGold.withOpacity(0.5), size: 16),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
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
          borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownField<T>({required T? value, required String hint, required bool isDark, required IconData icon, required List<DropdownMenuItem<T>> items, required Function(T?) onChanged, String? Function(T?)? validator}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          decoration: InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(icon, color: AppTheme.accentGold.withOpacity(0.5), size: 16),
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
          ),
          items: items,
          onChanged: onChanged,
          validator: validator,
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, bool isDark, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: AppTheme.accentGold,
                  onPrimary: Colors.black,
                  surface: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  onSurface: isDark ? Colors.white : Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (d != null) onSelect(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentGold.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: AppTheme.accentGold.withOpacity(0.5), size: 16),
            const SizedBox(width: 12),
            Text(
              date == null ? 'Choisir date' : DateFormat('dd/MM/yyyy').format(date),
              style: TextStyle(
                color: date == null 
                  ? (isDark ? Colors.white24 : Colors.black26)
                  : (isDark ? Colors.white : Colors.black87),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    // Step 1: Upload new contract file if admin attached one
    if (widget.project != null && _contractBytes != null && _contractFilename != null) {
      setState(() => _isUploadingContract = true);
      final uploadResult = await ProjectService.uploadContract(
        widget.project!.id!,
        _contractBytes!,
        _contractFilename!,
      );
      setState(() { _isUploadingContract = false; _projectHasContract = uploadResult['success']; });
      if (!uploadResult['success'] && mounted) {
        setState(() => _isSaving = false);
        LuxuryStatusDialog.show(context, isSuccess: false, title: 'Erreur contrat', message: uploadResult['message']);
        return;
      }
    }
    
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
      if (result['success']) {
        widget.onSave();
        Navigator.pop(context);
        LuxuryStatusDialog.show(
          context,
          isSuccess: true,
          title: widget.project == null ? 'Project Initialized' : 'Project Refined',
          message: result['message'] ?? 'The project timeline has been synchronized with the core engine.',
        );
      } else {
        setState(() => _isSaving = false);
        // Specific targeting for contract gate
        if (result['error'] == 'contract_required') {
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Contrat Requis',
            message: 'Un contrat d\'engagement signé avec le client doit être uploadé avant de démarrer ce projet. Veuillez attacher le document PDF ci-dessus.',
          );
        } else {
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Planning Fault',
            message: result['message'] ?? 'Architecture validation failed for the requested project parameters.',
          );
        }
      }
    }
  }

  Widget _buildContractUploadSection(bool isDark) {
    final hasExistingContract = _projectHasContract;
    final hasPendingUpload = _contractBytes != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasExistingContract 
          ? Colors.green.withOpacity(0.06)
          : hasPendingUpload
              ? AppTheme.accentGold.withOpacity(0.08)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasExistingContract 
            ? Colors.green.withOpacity(0.3)
            : hasPendingUpload 
                ? AppTheme.accentGold.withOpacity(0.5)
                : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasExistingContract 
              ? Icons.verified_rounded 
              : hasPendingUpload 
                  ? Icons.attach_file_rounded 
                  : Icons.description_outlined,
            color: hasExistingContract 
              ? Colors.green 
              : hasPendingUpload 
                  ? AppTheme.accentGold 
                  : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasExistingContract 
                    ? 'Contrat uploadé ✓'
                    : hasPendingUpload 
                        ? _contractFilename ?? 'Prêt à uploader'
                        : 'Aucun contrat attaché',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasExistingContract 
                      ? Colors.green 
                      : hasPendingUpload 
                          ? AppTheme.accentGold
                          : Colors.grey,
                  ),
                ),
                if (!hasExistingContract && !hasPendingUpload)
                  const Text(
                    'Requis pour démarrer le projet',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                if (hasPendingUpload && !hasExistingContract)
                  const Text(
                    'Sera uploadé à la sauvegarde',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (_isUploadingContract)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGold))
          else
            TextButton.icon(
              onPressed: _pickContractFile,
              icon: Icon(hasExistingContract ? Icons.refresh_rounded : Icons.upload_file_rounded, size: 16),
              label: Text(hasExistingContract ? 'Remplacer' : 'Joindre', style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentGold),
            ),
        ],
      ),
    );
  }

  Future<void> _pickContractFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _contractBytes = result.files.single.bytes!;
        _contractFilename = result.files.single.name;
      });
    }
  }
}



