import 'package:flutter/material.dart';
import 'package:fs_hub/features/hr/data/models/remote_work_model.dart';
import 'package:fs_hub/features/hr/data/services/hr_service.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:intl/intl.dart';

class RemoteWorkRequestModal extends StatefulWidget {
  const RemoteWorkRequestModal({super.key});

  @override
  State<RemoteWorkRequestModal> createState() => _RemoteWorkRequestModalState();
}

class _RemoteWorkRequestModalState extends State<RemoteWorkRequestModal> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'occasional';
  DateTime? _selectedDate;
  final _reasonCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 32),
              
              _buildLabel('Type de télétravail', isDark),
              const SizedBox(height: 12),
              _buildTypeDropdown(isDark),
              const SizedBox(height: 24),
              
              _buildLabel('Date souhaitée', isDark),
              const SizedBox(height: 12),
              _buildDatePicker(isDark),
              const SizedBox(height: 24),
              
              _buildLabel('Motif (Optionnel)', isDark),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: _buildInputDecoration('Précisez le motif...', isDark),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 40),
              
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Demande Télétravail',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, size: 20, color: isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
    );
  }

  Widget _buildTypeDropdown(bool isDark) {
    final types = {
      'occasional': 'Occasionnel',
      'regular': 'Régulier / Hebdomadaire',
      'full_remote': 'Full Remote Exceptionnel',
    };

    return DropdownButtonFormField<String>(
      value: _type,
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      decoration: _buildInputDecoration('', isDark),
      items: types.entries.map((e) => DropdownMenuItem(
        value: e.key,
        child: Text(e.value, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      )).toList(),
      onChanged: (v) => setState(() => _type = v!),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    final dateText = _selectedDate == null 
        ? 'Choisir une date' 
        : DateFormat.yMMMMd().format(_selectedDate!);

    return InkWell(
      onTap: () async {
        final result = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFC9A24D),
                  primary: const Color(0xFFC9A24D),
                  onPrimary: Colors.white,
                  surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (result != null) setState(() => _selectedDate = result);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: const Color(0xFFC9A24D)),
            const SizedBox(width: 16),
            Text(
              dateText,
              style: TextStyle(
                color: _selectedDate == null 
                  ? (isDark ? Colors.white38 : Colors.black38)
                  : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC9A24D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Soumettre la Demande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _submit() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir une date')));
      return;
    }

    setState(() => _isLoading = true);
    
    final user = await AuthService.getCurrentUser();
    if (user == null) {
       setState(() => _isLoading = false);
       return;
    }

    final request = RemoteWork(
      employeeId: user['id'].toString(),
      type: _type,
      remoteDate: _selectedDate!,
      status: 'pending',
      reason: _reasonCtrl.text.trim(),
    );

    final result = await HrService.submitRemoteWorkRequest(request);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Demande de télétravail envoyée !'),
            backgroundColor: Colors.green,
          )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Erreur lors de l\'envoi'),
            backgroundColor: Colors.redAccent,
          )
        );
      }
    }
  }
}
