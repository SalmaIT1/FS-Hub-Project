import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/attendance_model.dart';

class HrAttendancePage extends StatefulWidget {
  const HrAttendancePage({super.key});

  @override
  State<HrAttendancePage> createState() => _HrAttendancePageState();
}

class _HrAttendancePageState extends State<HrAttendancePage> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdCtrl = TextEditingController();
  final _statusCtrl = TextEditingController(text: 'present');
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final record = Attendance(
      employeeId: _employeeIdCtrl.text.trim(),
      attendanceDate: DateTime.now(),
      status: _statusCtrl.text.trim(),
    );

    final success = await HrService.logAttendance(record);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance logged')));
        Navigator.pop(context);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to log attendance')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Attendance',
      showBackButton: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
             ? const Center(child: CircularProgressIndicator())
             : Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _employeeIdCtrl,
                  decoration: const InputDecoration(labelText: 'Employee ID (User ID)'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _statusCtrl.text,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['present', 'late', 'absent', 'half_day', 'remote', 'leave']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                  onChanged: (v) {
                    if (v != null) _statusCtrl.text = v;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Log Attendance'),
                ),
              ],
            ),
          )
        ),
      ),
    );
  }
}
