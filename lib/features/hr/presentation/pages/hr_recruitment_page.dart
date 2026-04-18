import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/features/employees/services/employee_service.dart';
import 'package:fs_hub/shared/models/employee_model.dart';

const _gold = Color(0xFFC9A24D);

class HrRecruitmentPage extends StatefulWidget {
  const HrRecruitmentPage({super.key});

  @override
  State<HrRecruitmentPage> createState() => _HrRecruitmentPageState();
}

class _HrRecruitmentPageState extends State<HrRecruitmentPage> {
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final employees = await EmployeeService.getAllEmployees();
    if (mounted) {
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F6F6);

    return Scaffold(
      backgroundColor: bg,
      appBar: LuxuryAppBar(
        title: isFr ? 'Recrutement' : 'Recruitment',
        subtitle: isFr ? 'Gestion des documents & contrats' : 'Document & Contracts Management',
        isPremium: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final emp = _employees[index];
                return _buildEmployeeCard(emp, isDark, isFr);
              },
            ),
    );
  }

  Widget _buildEmployeeCard(Employee emp, bool isDark, bool isFr) {
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    // Simple calculation to see how many documents are provided
    int docsCount = 0;
    if (emp.cvDocument != null && emp.cvDocument!.isNotEmpty) docsCount++;
    if (emp.cinDocument != null && emp.cinDocument!.isNotEmpty) docsCount++;
    if (emp.bacDocument != null && emp.bacDocument!.isNotEmpty) docsCount++;
    if (emp.degreeDocument != null && emp.degreeDocument!.isNotEmpty) docsCount++;
    if (emp.transcriptsDocuments != null && emp.transcriptsDocuments!.isNotEmpty) docsCount++;

    final progress = docsCount / 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _gold.withOpacity(0.2),
                backgroundImage: emp.avatarUrl != null ? NetworkImage(emp.avatarUrl!) : null,
                child: emp.avatarUrl == null
                    ? Text(emp.nom.isNotEmpty ? emp.nom[0].toUpperCase() : '?', style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 20))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                    Text(emp.poste, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$docsCount/5 Docs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 60,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(progress == 1.0 ? Colors.green : _gold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _manageDocuments(emp, isFr),
                  icon: const Icon(Icons.folder_shared_rounded, size: 18),
                  label: Text(isFr ? 'Documents' : 'Documents'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold,
                    side: const BorderSide(color: _gold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: progress >= 0.8 ? () => _generateContract(emp, isFr) : null,
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: Text(isFr ? 'Contrat' : 'Contract'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _manageDocuments(Employee emp, bool isFr) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DocumentsSheet(employee: emp, isFr: isFr),
    );

    if (updated == true) {
      _loadEmployees();
    }
  }

  void _generateContract(Employee emp, bool isFr) {
    // Simulated PDF generation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 10),
            Text(isFr ? 'Contrat Généré' : 'Contract Generated'),
          ],
        ),
        content: Text(
          isFr 
             ? 'Le contrat PDF pour ${emp.fullName} a été généré avec succès en utilisant ses documents vérifiés.\n\nType: ${emp.typeContrat}\nPoste: ${emp.poste}'
             : 'PDF Contract for ${emp.fullName} has been generated successfully using their verified documents.\n\nType: ${emp.typeContrat}\nRole: ${emp.poste}'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isFr ? 'Fermer' : 'Close', style: const TextStyle(color: _gold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold),
            onPressed: () => Navigator.pop(context),
            child: Text(isFr ? 'Télécharger PDF' : 'Download PDF', style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

class _DocumentsSheet extends StatefulWidget {
  final Employee employee;
  final bool isFr;

  const _DocumentsSheet({required this.employee, required this.isFr});

  @override
  State<_DocumentsSheet> createState() => _DocumentsSheetState();
}

class _DocumentsSheetState extends State<_DocumentsSheet> {
  late TextEditingController _cvCtrl;
  late TextEditingController _cinCtrl;
  late TextEditingController _bacCtrl;
  late TextEditingController _degCtrl;
  late TextEditingController _trsCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cvCtrl = TextEditingController(text: widget.employee.cvDocument);
    _cinCtrl = TextEditingController(text: widget.employee.cinDocument);
    _bacCtrl = TextEditingController(text: widget.employee.bacDocument);
    _degCtrl = TextEditingController(text: widget.employee.degreeDocument);
    _trsCtrl = TextEditingController(text: widget.employee.transcriptsDocuments);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isFr ? 'Documents de Recrutement' : 'Recruitment Documents',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          Text(widget.employee.fullName, style: const TextStyle(color: _gold, fontSize: 16)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildUploadField('CV (Curriculum Vitae)', _cvCtrl),
                _buildUploadField('Copie CIN', _cinCtrl),
                _buildUploadField('Document de BAC', _bacCtrl),
                _buildUploadField('Diplôme (Licence/Mastère/Ing)', _degCtrl),
                _buildUploadField('Relevés de notes', _trsCtrl),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving ? null : _saveDocuments,
              child: _isSaving
                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                 : Text(
                     widget.isFr ? 'Sauvegarder les documents' : 'Save Documents',
                     style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                   ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'URL of the document / Cloud link',
          prefixIcon: const Icon(Icons.link_rounded),
          suffixIcon: controller.text.isNotEmpty 
             ? const Icon(Icons.check_circle, color: Colors.green)
             : const Icon(Icons.upload_file_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (_) => setState((){}), // rebuild to show/hide checkmark
      ),
    );
  }

  void _saveDocuments() async {
    setState(() => _isSaving = true);
    try {
      final updatedEmp = widget.employee.copyWith(
        cvDocument: _cvCtrl.text.trim(),
        cinDocument: _cinCtrl.text.trim(),
        bacDocument: _bacCtrl.text.trim(),
        degreeDocument: _degCtrl.text.trim(),
        transcriptsDocuments: _trsCtrl.text.trim(),
      );
      
      await EmployeeService.updateEmployee(updatedEmp.id!, updatedEmp);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
