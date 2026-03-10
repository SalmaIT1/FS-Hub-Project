import 'package:flutter/material.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/features/auth/services/role_service.dart';
import 'package:fs_hub/features/auth/services/permission_service.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';

class RolesPermissionsPage extends StatefulWidget {
  const RolesPermissionsPage({super.key});

  @override
  State<RolesPermissionsPage> createState() => _RolesPermissionsPageState();
}

class _RolesPermissionsPageState extends State<RolesPermissionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        RoleService.getAllRoles(),
        PermissionService.getAllPermissions(),
      ]);
      if (mounted) {
        setState(() {
          _roles = results[0];
          _permissions = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStatus('Failed to load data: $e', success: false);
      }
    }
  }

  void _showStatus(String message, {bool success = true}) {
    LuxuryStatusDialog.show(
      context,
      isSuccess: success,
      title: success ? 'Success' : 'Error',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: 'Roles & Permissions',
      subtitle: 'Access Control Management',
      isPremium: true,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.accentGold,
        indicatorWeight: 4,
        labelColor: AppTheme.accentGold,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'ROLES'),
          Tab(text: 'PERMISSIONS'),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 150),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: isDark
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildRolesTab(isDark),
                  _buildPermissionsTab(isDark),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _triggerAddAction(),
        backgroundColor: AppTheme.accentGold,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRolesTab(bool isDark) {
    if (_roles.isEmpty) return _buildEmptyState('No roles found.', isDark);
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _roles.length,
        itemBuilder: (context, index) => _buildRoleCard(_roles[index], isDark),
      ),
    );
  }

  Widget _buildPermissionsTab(bool isDark) {
    if (_permissions.isEmpty) return _buildEmptyState('No permissions found.', isDark);
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _permissions.length,
        itemBuilder: (context, index) => _buildPermissionCard(_permissions[index], isDark),
      ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_person_outlined, size: 80, color: AppTheme.accentGold.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role, bool isDark) {
    final permissions = List<Map<String, dynamic>>.from(role['permissions'] ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(role['nom'] ?? 'Unnamed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                    onPressed: () => _showAddDialog(role: role),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteRole(role['id']),
                  ),
                ],
              ),
            ],
          ),
          if (role['description'] != null)
            Text(role['description'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          const Text('Permissions:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentGold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: permissions.isEmpty
                ? [const Text('No permissions assigned', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic))]
                : permissions.map((p) => Chip(
                    label: Text(p['nom'] ?? '', style: const TextStyle(fontSize: 10)),
                    backgroundColor: AppTheme.accentGold.withOpacity(0.1),
                    deleteIcon: const Icon(Icons.close, size: 12),
                    onDeleted: () => _removePermissionFromRole(role['id'], p['id']),
                  )).toList(),
          ),
          TextButton.icon(
            onPressed: () => _showPermissionAssignmentDialog(role),
            icon: const Icon(Icons.add_moderator_outlined, size: 18),
            label: const Text('Manage Permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(Map<String, dynamic> permission, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: _cardDecoration(isDark),
      child: Row(
        children: [
          const Icon(Icons.key_outlined, color: AppTheme.accentGold, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(permission['nom'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (permission['module'] != null)
                  Text(permission['module'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1.2)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showAddPermissionDialog(permission: permission),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () => _deletePermission(permission['id']),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.accentGold.withOpacity(0.1)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
    );
  }

  // --- CRUD Operations ---

  void _showAddDialog({Map<String, dynamic>? role}) {
    final nameController = TextEditingController(text: role?['nom']);
    final descController = TextEditingController(text: role?['description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(role == null ? 'New Role' : 'Edit Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Project Manager')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {'nom': nameController.text, 'description': descController.text};
              final result = role == null
                  ? await RoleService.createRole(data)
                  : await RoleService.updateRole(role['id'], data);
              
              if (mounted) {
                Navigator.pop(context);
                if (result['success']) {
                  _showStatus(result['message']);
                  _loadData();
                } else {
                  _showStatus(result['message'], success: false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddPermissionDialog({Map<String, dynamic>? permission}) {
    final nameController = TextEditingController(text: permission?['nom']);
    final moduleController = TextEditingController(text: permission?['module']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(permission == null ? 'New Permission' : 'Edit Permission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Action Name', hintText: 'e.g. view_reports')),
            TextField(controller: moduleController, decoration: const InputDecoration(labelText: 'Module', hintText: 'e.g. finance')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {'nom': nameController.text, 'module': moduleController.text};
              final result = permission == null
                  ? await PermissionService.createPermission(data)
                  : await PermissionService.updatePermission(permission['id'], data);
              
              if (mounted) {
                Navigator.pop(context);
                if (result['success']) {
                  _showStatus(result['message']);
                  _loadData();
                } else {
                  _showStatus(result['message'], success: false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRole(int id) async {
    final confirmed = await _showConfirmDialog('Delete Role', 'Are you sure you want to delete this role?');
    if (confirmed == true) {
      final result = await RoleService.deleteRole(id);
      if (result['success']) {
        _showStatus('Role deleted');
        _loadData();
      } else {
        _showStatus(result['message'], success: false);
      }
    }
  }

  Future<void> _deletePermission(int id) async {
    final confirmed = await _showConfirmDialog('Delete Permission', 'Note: This might affect roles assigned to this permission.');
    if (confirmed == true) {
      final result = await PermissionService.deletePermission(id);
      if (result['success']) {
        _showStatus('Permission deleted');
        _loadData();
      } else {
        _showStatus(result['message'], success: false);
      }
    }
  }

  void _showPermissionAssignmentDialog(Map<String, dynamic> role) async {
    final currentPermIds = (role['permissions'] as List? ?? []).map((p) => p['id'] as int).toList();
    final selectedIds = List<int>.from(currentPermIds);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Permissions for ${role['nom']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _permissions.length,
              itemBuilder: (context, index) {
                final p = _permissions[index];
                return CheckboxListTile(
                  title: Text(p['nom'] ?? ''),
                  subtitle: Text(p['module'] ?? ''),
                  value: selectedIds.contains(p['id']),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selectedIds.add(p['id']);
                      } else {
                        selectedIds.remove(p['id']);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final result = await RoleService.assignPermissionsToRole(role['id'], selectedIds);
                if (mounted) {
                  Navigator.pop(context);
                  if (result['success']) {
                    _showStatus('Permissions updated');
                    _loadData();
                  } else {
                    _showStatus(result['message'], success: false);
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePermissionFromRole(int roleId, int permId) async {
    final role = _roles.firstWhere((r) => r['id'] == roleId);
    final currentPermIds = (role['permissions'] as List? ?? []).map((p) => p['id'] as int).toList();
    currentPermIds.remove(permId);
    
    final result = await RoleService.assignPermissionsToRole(roleId, currentPermIds);
    if (result['success']) {
      _loadData();
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _triggerAddAction() {
    if (_tabController.index == 0) {
      _showAddDialog();
    } else {
      _showAddPermissionDialog();
    }
  }
}
