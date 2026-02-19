import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../domain/chat_entities.dart';
import '../state/chat_controller.dart';
import 'avatar_helper.dart';

class GroupCreationPage extends StatefulWidget {
  final ChatController controller;
  final Function(ConversationEntity) onGroupCreated;

  const GroupCreationPage({
    Key? key,
    required this.controller,
    required this.onGroupCreated,
  }) : super(key: key);

  @override
  State<GroupCreationPage> createState() => _GroupCreationPageState();
}

class _GroupCreationPageState extends State<GroupCreationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  Future<List<Map<String, dynamic>>>? _usersFuture;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = widget.controller.getAvailableUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _handleCreateGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }

    // Capture states before async await
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isCreating = true);

    try {
      final conversation = await widget.controller.createGroupConversation(
        participantIds: _selectedUserIds.toList(),
        name: _nameController.text.trim(),
        type: 'group',
      );

      if (conversation != null) {
        // Correct order: pop current page, THEN trigger success callback (which pushes thread)
        navigator.pop();
        widget.onGroupCreated(conversation);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error creating group: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.baseDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              DesignTokens.baseDark,
              DesignTokens.baseDark.withOpacity(0.8),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              _buildHeader(context),

              // ── Group Name Input ──────────────────────────────────
              _buildNameInput(),

              // ── Search Input ────────────────────────────────────────
              _buildSearchInput(),

              // ── User List ───────────────────────────────────────────
              Expanded(
                child: _buildUserList(),
              ),

              // ── Create Button ───────────────────────────────────────
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: DesignTokens.textLight),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'New Group',
            style: DesignTokens.headingS.copyWith(
              color: DesignTokens.textLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (_selectedUserIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DesignTokens.accentGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignTokens.accentGold.withOpacity(0.3)),
              ),
              child: Text(
                '${_selectedUserIds.length} selected',
                style: DesignTokens.caption.copyWith(
                  color: DesignTokens.accentGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: DesignTokens.surfaceGlass.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: _nameController,
          style: DesignTokens.bodyL,
          decoration: InputDecoration(
            hintText: 'Group Name',
            hintStyle: DesignTokens.bodyM.copyWith(color: DesignTokens.textSecondary),
            prefixIcon: const Icon(Icons.group_add_rounded,
                color: DesignTokens.accentGold, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: TextField(
          controller: _searchController,
          style: DesignTokens.bodyL.copyWith(fontSize: 14),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Find participants…',
            hintStyle: DesignTokens.bodyM.copyWith(color: DesignTokens.textSecondary),
            prefixIcon: Icon(Icons.search_rounded,
                color: DesignTokens.textSecondary, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: DesignTokens.accentGold),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading users', style: DesignTokens.bodyM),
          );
        }

        final users = snapshot.data ?? [];
        final searchText = _searchController.text.toLowerCase();
        final filtered = users.where((u) {
          final username = (u['username'] as String).toLowerCase();
          final firstName = (u['firstName'] as String? ?? '').toLowerCase();
          final lastName = (u['lastName'] as String? ?? '').toLowerCase();
          return username.contains(searchText) ||
              firstName.contains(searchText) ||
              lastName.contains(searchText);
        }).toList();

        if (filtered.isEmpty) {
          return Center(child: Text('No users found', style: DesignTokens.bodyM));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final user = filtered[index];
            final userId = user['id'].toString();
            final isSelected = _selectedUserIds.contains(userId);
            final fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
            final displayName = fullName.isEmpty ? user['username'] : fullName;

            return _UserListTile(
              user: user,
              displayName: displayName,
              isSelected: isSelected,
              onTap: () => _toggleUser(userId),
            );
          },
        );
      },
    );
  }

  Widget _buildCreateButton() {
    final canCreate = _selectedUserIds.isNotEmpty && _nameController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: canCreate
              ? LinearGradient(
                  colors: [DesignTokens.accentGold, const Color(0xFF8B6914)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: canCreate ? null : Colors.white.withOpacity(0.05),
          boxShadow: canCreate
              ? [
                  BoxShadow(
                    color: DesignTokens.accentGold.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: canCreate && !_isCreating ? _handleCreateGroup : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isCreating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Create Group',
                  style: DesignTokens.bodyL.copyWith(
                    color: canCreate ? Colors.white : Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String displayName;
  final bool isSelected;
  final VoidCallback onTap;

  const _UserListTile({
    required this.user,
    required this.displayName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Selection Indicator
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? DesignTokens.accentGold
                        : Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                  color: isSelected ? DesignTokens.accentGold : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),

              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: const Center(
                  child: Icon(Icons.person_outline_rounded,
                      color: DesignTokens.textSecondary, size: 22),
                ),
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: DesignTokens.bodyL.copyWith(
                        fontSize: 14,
                        color: isSelected ? DesignTokens.textLight : DesignTokens.textLight.withOpacity(0.8),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '@${user['username']}',
                      style: DesignTokens.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
