import 'package:flutter/material.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/leave_request_model.dart';
import 'package:intl/intl.dart';

class HrLeavesPage extends StatefulWidget {
  const HrLeavesPage({super.key});

  @override
  State<HrLeavesPage> createState() => _HrLeavesPageState();
}

class _HrLeavesPageState extends State<HrLeavesPage> {
  List<LeaveRequest> _leaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await HrService.getLeaveRequests();
    if (mounted) setState(() { _leaves = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Leaves',
      showBackButton: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
              itemCount: _leaves.length,
              itemBuilder: (ctx, i) {
                final l = _leaves[i];
                return Card(
                  child: ListTile(
                    title: Text('${l.leaveType.toUpperCase()} - ${l.employeeId}'),
                    subtitle: Text('${DateFormat.yMd().format(l.startDate)} to ${DateFormat.yMd().format(l.endDate)}'),
                    trailing: Text(l.status.toUpperCase(), style: TextStyle(
                      color: l.status == 'approved' ? Colors.green : (l.status == 'rejected' ? Colors.red : Colors.orange),
                    )),
                  ),
                );
              },
          )
        ),
      ),
    );
  }
}
