import 'package:flutter/material.dart';
import '../models/demand.dart';

class DemandCard extends StatelessWidget {
  final Demand demand;
  final VoidCallback? onTap;

  const DemandCard({
    super.key,
    required this.demand,
    this.onTap,
  });

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'password_reset':
        return 'Password Reset';
      case 'hardware':
        return 'Hardware';
      case 'administrative':
        return 'Administrative';
      case 'custom':
        return 'Custom';
      default:
        return type;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'password_reset':
        return Icons.lock_reset;
      case 'hardware':
        return Icons.computer;
      case 'administrative':
        return Icons.receipt;
      case 'custom':
        return Icons.edit_note;
      default:
        return Icons.help_outline;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor(demand.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getIconForType(demand.type),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTypeDisplayName(demand.type),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          demand.description.length > 60
                              ? '${demand.description.substring(0, 60)}...'
                              : demand.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(demand.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(demand.status),
                      ),
                    ),
                    child: Text(
                      _getStatusDisplayName(demand.status),
                      style: TextStyle(
                        color: _getStatusColor(demand.status),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'Created: ${_formatDate(demand.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}