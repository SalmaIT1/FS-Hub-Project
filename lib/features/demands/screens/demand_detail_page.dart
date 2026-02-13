import 'package:flutter/material.dart';
import '../../../shared/models/demand_model.dart';
import '../services/demand_service.dart';
import '../../auth/data/services/auth_service.dart';

class DemandDetailPage extends StatefulWidget {
  final Demand demand;

  const DemandDetailPage({
    Key? key,
    required this.demand,
  }) : super(key: key);

  @override
  State<DemandDetailPage> createState() => _DemandDetailPageState();
}

class _DemandDetailPageState extends State<DemandDetailPage> {
  late Demand _demand;
  bool _isLoading = false;
  String? _selectedStatus;
  final TextEditingController _resolutionNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _demand = widget.demand;
  }

  Future<void> _updateDemandStatus(String status) async {
    // Call the method with empty notes
    await _updateDemandStatusWithNotes(status, '');
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'password_reset':
        return 'Password Reset';
      case 'hardware':
        return 'Hardware';
      case 'software':
        return 'Software';
      case 'access':
        return 'Access';
      default:
        return type;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'resolved':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Future<String?> _showResolutionNotesDialog(String title, String labelText) async {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: labelText),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDemandStatusWithNotes(String status, String resolutionNotes) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user to record who handled the demand
      final currentUser = await AuthService.getCurrentUser();
      final currentUserId = currentUser?['id'];
      
      final updateData = {
        'status': status,
        if (currentUserId != null) 'handledBy': currentUserId,
        'resolutionNotes': resolutionNotes,
      };
      
      final result = await DemandService.updateDemand(
        _demand.id.toString(), 
        updateData
      );

      if (result['success']) {
        // Refresh the demand data to get the latest status and handled_by info
        final refreshedResult = await DemandService.getDemandById(_demand.id.toString());
        if (refreshedResult['success']) {
          setState(() {
            _demand = refreshedResult['data'];
            _selectedStatus = null; // Reset selection after update
            _resolutionNotesController.clear(); // Clear notes after successful update
            _isLoading = false;
          });
        } else {
          setState(() {
            _demand = Demand(
              id: _demand.id,
              type: _demand.type,
              description: _demand.description,
              requesterId: _demand.requesterId,
              requesterName: _demand.requesterName,
              status: status,
              createdAt: _demand.createdAt,
              handledBy: _demand.handledBy, // This will be updated by the backend
              handlerName: _demand.handlerName,
              resolutionNotes: _demand.resolutionNotes,
            );
            _selectedStatus = null; // Reset selection after update
            _resolutionNotesController.clear(); // Clear notes after successful update
            _isLoading = false;
          });
        }

        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Demand ${status.toUpperCase()} successfully')),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to update demand')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating demand: $e')),
        );
      }
    }
  }

  Future<void> _showStatusChangeConfirmationDialog(String newStatus) async {
    final String currentStatus = _demand.status;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Status Change'),
          content: Text('Are you sure you want to change the status from "${_getStatusDisplayName(currentStatus)}" to "${_getStatusDisplayName(newStatus)}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = newStatus;
                });
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Confirm ${_getStatusDisplayName(newStatus)}'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard(String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demand Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Demand Info Card
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(_demand.status),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getStatusColor(_demand.status).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getStatusColor(_demand.status) == Colors.green
                                        ? Icons.check_circle
                                        : _getStatusColor(_demand.status) == Colors.red
                                            ? Icons.cancel
                                            : _getStatusColor(_demand.status) == Colors.orange
                                                ? Icons.pending_actions
                                                : _getStatusColor(_demand.status) == Colors.blue
                                                    ? Icons.done_all
                                                    : Icons.help_outline,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getTypeDisplayName(_demand.type),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Status: ${_getStatusDisplayName(_demand.status)}',
                                        style: TextStyle(
                                          color: _getStatusColor(_demand.status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Requester Information
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildInfoCard('Requester', _demand.requesterName.isEmpty ? 'N/A' : _demand.requesterName, isDark),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildInfoCard('Requester ID', _demand.requesterId, isDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? Colors.grey.shade800.withOpacity(0.5) 
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Description',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _demand.description,
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black87,
                                      height: 1.5,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Created: ${_formatDate(_demand.createdAt)}',
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(_demand.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _getStatusColor(_demand.status),
                                    ),
                                  ),
                                  child: Text(
                                    _getStatusDisplayName(_demand.status),
                                    style: TextStyle(
                                      color: _getStatusColor(_demand.status),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Show resolution information if demand is not pending
                    if (_demand.status != 'pending')
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outlined,
                                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Resolution Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_demand.handledBy != null && _demand.handlerName != null) ...[
                                _buildInfoItem('Handled by', _demand.handlerName ?? 'N/A', Icons.person, isDark),
                                const SizedBox(height: 12),
                              ],
                              if (_demand.resolutionNotes != null && _demand.resolutionNotes!.isNotEmpty) ...[
                                _buildInfoItem('Resolution Notes', _demand.resolutionNotes!, Icons.notes, isDark),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Action Controls (show status selector if demand is not resolved)
                    if (_demand.status != 'resolved')
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Update Status',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Status Selection Dropdown
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isDark ? Colors.grey.shade800 : Colors.white,
                                ),
                                child: DropdownButton<String>(
                                  value: _demand.status,
                                  hint: const Text('Select status'),
                                  underline: Container(),
                                  isExpanded: true,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  items: <String>['pending', 'approved', 'rejected', 'in_progress', 'resolved']
                                      .map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        _getStatusDisplayName(value),
                                        style: TextStyle(
                                          color: _getStatusColor(value),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null && newValue != _demand.status) {
                                      _showStatusChangeConfirmationDialog(newValue);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Resolution Notes Section
                              Text(
                                'Resolution Notes:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isDark 
                                      ? Colors.grey.shade800.withOpacity(0.5) 
                                      : Colors.grey.shade50,
                                ),
                                child: TextFormField(
                                  controller: _resolutionNotesController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: 'Enter notes about the status change...',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Update Status Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    String statusToUpdate = _selectedStatus ?? _demand.status;
                                    if (_resolutionNotesController.text.trim().isNotEmpty) {
                                      _updateDemandStatusWithNotes(statusToUpdate, _resolutionNotesController.text.trim());
                                    } else {
                                      _updateDemandStatusWithNotes(statusToUpdate, '');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Update Status',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}