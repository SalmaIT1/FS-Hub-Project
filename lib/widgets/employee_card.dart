import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../shared/models/employee_model.dart';

class EmployeeCard extends StatefulWidget {
  final Employee employee;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EmployeeCard({
    super.key,
    required this.employee,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<EmployeeCard> {
  bool _isPressed = false;

  Color _getStatusColor() {
    switch (widget.employee.statut.toLowerCase()) {
      case 'actif':
        return const Color(0xFF4CAF50);
      case 'suspendu':
        return const Color(0xFFFFA726);
      case 'démission':
        return const Color(0xFFEF5350);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isPressed
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                      : (isDark 
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08)),
                  width: 1.0,
                ),
                boxShadow: [
                  if (_isPressed)
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _buildAvatar(isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.employee.fullName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.employee.poste,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.employee.departement,
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.onEdit != null || widget.onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      onSelected: (value) {
                        if (value == 'edit' && widget.onEdit != null) {
                          widget.onEdit!();
                        } else if (value == 'delete' && widget.onDelete != null) {
                          widget.onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (widget.onEdit != null)
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Color(0xFFEF5350),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: widget.employee.avatarUrl != null
            ? _buildImageWidget(widget.employee.avatarUrl!, isDark)
            : _buildAvatarPlaceholder(isDark),
      ),
    );
  }

  Widget _buildImageWidget(String avatarUrl, bool isDark) {
    final prefixLength = avatarUrl.length < 20 ? avatarUrl.length : 20;



    
    // Check if the URL is already a complete data URL
    if (avatarUrl.startsWith('data:')) {
      // This is already a complete data URL
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          
          return _buildAvatarPlaceholder(isDark);
        },
      );
    } else if (avatarUrl.length > 100) { // Likely a base64 string if it's long
      // Assume it's a base64 string and convert to data URL
      try {
        // Validate that it's a proper base64 string
        base64Decode(avatarUrl);
        
        // Create a data URL with base64 image data
        String dataUrl = 'data:image/jpeg;base64,$avatarUrl';
        
        return Image.network(
          dataUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            
            return _buildAvatarPlaceholder(isDark);
          },
        );
      } catch (e) {
        
        return _buildAvatarPlaceholder(isDark);
      }
    } else {
      // This is a regular URL
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildAvatarPlaceholder(isDark);
        },
      );
    }
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    return Container(
      color: isDark 
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.04),
      child: Center(
        child: Text(
          widget.employee.prenom[0].toUpperCase() + 
          widget.employee.nom[0].toUpperCase(),
          style: TextStyle(
            color: const Color(0xFFD4AF37),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor().withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        widget.employee.statut,
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
