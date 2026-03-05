import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/settings_controller.dart';
import '../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/demands/services/demand_service.dart';
import '../../shared/widgets/luxury/luxury_status_dialog.dart';

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitIssue() async {
    if (_titleController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill and provide details.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) throw Exception('Not logged in');

      final result = await DemandService.createDemand({
        'type': 'custom',
        'description': '🚨 Issue: ${_titleController.text.trim()}\n\n${_descController.text.trim()}',
      });

      if (mounted) {
        if (result['success']) {
          LuxuryStatusDialog.show(
            context,
            isSuccess: true,
            title: 'Issue Transmitted',
            message: 'Your report has been encrypted and sent to administration.',
          );
          _titleController.clear();
          _descController.clear();
        } else {
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Transmission Error',
            message: result['message'] ?? 'Quantum link failure during submission.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        LuxuryStatusDialog.show(
          context,
          isSuccess: false,
          title: 'System Fault',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LuxuryScaffold(
      title: settings.translate('report_issue'),
      showBackButton: true,
      onBackPress: () => Navigator.pop(context),
      isPremium: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text(
              'Report a Technical Issue',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Describe the issue you are facing. This will be sent directly to the administrative team as a high-priority request.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _titleController,
              label: 'Issue Summarized Title',
              icon: Icons.title,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descController,
              label: 'Detailed Description',
              icon: Icons.description_outlined,
              isDark: isDark,
              maxLines: 5,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _submitIssue,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'SUBMIT ISSUE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 2), // small visual fix depending on maxLines
          child: Icon(icon, color: AppTheme.accentGold),
        ),
        alignLabelWithHint: true, // for multiline
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.accentGold,
          ),
        ),
      ),
    );
  }
}
