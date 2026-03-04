import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/shared/models/finance_model.dart';
import 'package:fs_hub/features/finance/services/finance_service.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/features/projects/services/project_service.dart';
import 'package:fs_hub/shared/models/project_model.dart';
import 'package:fs_hub/features/clients/models/client_model.dart';

class InvoicesListPage extends StatefulWidget {
  const InvoicesListPage({super.key});

  @override
  State<InvoicesListPage> createState() => _InvoicesListPageState();
}

class _InvoicesListPageState extends State<InvoicesListPage> {
  List<Invoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final invoices = await FinanceService.getAllInvoices();
    if (mounted) {
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Payée':
        return Colors.green;
      case 'Envoyée':
        return Colors.blue;
      case 'En retard':
        return Colors.red;
      case 'Brouillon':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: LuxuryAppBar(
        title: settings.translate('invoices') ?? 'Invoices',
        subtitle: 'Manage billing and payments',
        isPremium: true,
      ),
      body: Container(
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
          : _invoices.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.request_quote_outlined, size: 64, color: AppTheme.accentGold.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    const Text('No invoices found', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _invoices.length,
                itemBuilder: (context, index) {
                  final invoice = _invoices[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildInvoiceCard(invoice, isDark),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddInvoiceDialog(),
        backgroundColor: AppTheme.accentGold,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('Add Invoice', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showInvoiceDetails(invoice),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        invoice.numeroFacture,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      _buildStatusTag(invoice.statut),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    invoice.projectNom ?? 'External Client',
                    style: TextStyle(color: AppTheme.accentGold.withOpacity(0.8), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Amount', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text(
                            '${invoice.montantTtc.toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Due Date', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text(
                            DateFormat('dd MMM yyyy').format(invoice.dateEcheance),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
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

  Widget _buildStatusTag(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showInvoiceDetails(Invoice invoice) {
    // Show details and payments
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InvoiceDetailsSheet(invoice: invoice, onUpdate: _loadInvoices),
    );
  }

  void _showAddInvoiceDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const _AddInvoiceDialog(),
    );
    if (result == true) {
      _loadInvoices();
    }
  }
}

class _AddInvoiceDialog extends StatefulWidget {
  const _AddInvoiceDialog();

  @override
  State<_AddInvoiceDialog> createState() => _AddInvoiceDialogState();
}

class _AddInvoiceDialogState extends State<_AddInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  String _num = '';
  double _ht = 0;
  double _tva = 20;
  int? _selectedProjectId;
  int? _selectedClientId;
  DateTime _dateEcheance = DateTime.now().add(const Duration(days: 30));
  
  List<Project> _projects = [];
  List<Client> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final projects = await ProjectService.getAllProjects();
      final clients = await ProjectService.getAvailableClients();
      if (mounted) {
        setState(() {
          _projects = projects;
          _clients = clients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Invoice'),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)))
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   DropdownButtonFormField<int>(
                    initialValue: _selectedProjectId,
                    decoration: const InputDecoration(labelText: 'Project (Optional)'),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('No Project')),
                      ..._projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nom))),
                    ],
                    onChanged: (v) => setState(() => _selectedProjectId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedClientId,
                    decoration: const InputDecoration(labelText: 'Client (Optional)'),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('No Client')),
                      ..._clients.map((c) => DropdownMenuItem(value: int.tryParse(c.id.toString()), child: Text(c.nom))),
                    ],
                    onChanged: (v) => setState(() => _selectedClientId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Invoice Number'),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    onChanged: (v) => _num = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Amount (HT)', suffixText: '€'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _ht = double.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'TVA (%)'),
                    keyboardType: TextInputType.number,
                    initialValue: '20',
                    onChanged: (v) => setState(() => _tva = double.tryParse(v) ?? 20),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Due Date'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(_dateEcheance)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dateEcheance,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setState(() => _dateEcheance = date);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total TTC: ${(_ht * (1 + _tva / 100)).toStringAsFixed(2)} €',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accentGold),
                  ),
                ],
              ),
            ),
          ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            if (_formKey.currentState?.validate() == true) {
              final invoice = Invoice(
                numeroFacture: _num,
                montantHt: _ht,
                tva: _tva,
                montantTtc: _ht * (1 + _tva / 100),
                dateEmission: DateTime.now(),
                dateEcheance: _dateEcheance,
                statut: 'Brouillon',
                projectId: _selectedProjectId,
                clientId: _selectedClientId,
              );
              final res = await FinanceService.createInvoice(invoice);
              if (res['success'] == true) {
                Navigator.pop(context, true);
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _InvoiceDetailsSheet extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onUpdate;

  const _InvoiceDetailsSheet({required this.invoice, required this.onUpdate});

  @override
  State<_InvoiceDetailsSheet> createState() => _InvoiceDetailsSheetState();
}

class _InvoiceDetailsSheetState extends State<_InvoiceDetailsSheet> {
  List<Payment> _payments = [];
  bool _loadingPayments = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final payments = await FinanceService.getPaymentsByInvoice(widget.invoice.id!);
    if (mounted) {
      setState(() {
        _payments = payments;
        _loadingPayments = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPaid = _payments.fold<double>(0, (sum, p) => sum + p.montant);
    final remaining = widget.invoice.montantTtc - totalPaid;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.invoice.numeroFacture, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(widget.invoice.projectNom ?? 'External Client', style: const TextStyle(color: AppTheme.accentGold)),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Financial Overview'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoTile('Total Amount', '${widget.invoice.montantTtc.toStringAsFixed(2)} €', isDark),
                      const SizedBox(width: 12),
                      _buildInfoTile('Total Paid', '${totalPaid.toStringAsFixed(2)} €', isDark, valueColor: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile('Remaining Balance', '${remaining.toStringAsFixed(2)} €', isDark, valueColor: remaining > 0 ? Colors.orange : Colors.green, fullWidth: true),
                  
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Payment History'),
                      TextButton.icon(
                        onPressed: () => _showAddPayment(context),
                        icon: const Icon(Icons.add, size: 18, color: AppTheme.accentGold),
                        label: const Text('Add Payment', style: TextStyle(color: AppTheme.accentGold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loadingPayments)
                    const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
                  else if (_payments.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No payments recorded yet.', style: TextStyle(color: Colors.grey)),
                    ))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final payment = _payments[index];
                        return _buildPaymentTile(payment, isDark);
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5));
  }

  Widget _buildInfoTile(String label, String value, bool isDark, {Color? valueColor, bool fullWidth = false}) {
    final body = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: body) : Expanded(child: body);
  }

  Widget _buildPaymentTile(Payment payment, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.accentGold.withOpacity(0.1),
            child: const Icon(Icons.payments_outlined, color: AppTheme.accentGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.mode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(DateFormat('dd MMM yyyy').format(payment.datePaiement), style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Text('+ ${payment.montant.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  void _showAddPayment(BuildContext context) async {
    final amountController = TextEditingController();
    String mode = 'Virement';
    
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount', suffixText: '€'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: const InputDecoration(labelText: 'Method'),
              items: ['Virement', 'Espèces', 'Carte', 'Chèque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => mode = v!,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text) ?? 0;
              if (amt > 0) {
                final payment = Payment(
                  factureId: widget.invoice.id!,
                  montant: amt,
                  mode: mode,
                  datePaiement: DateTime.now(),
                );
                final res = await FinanceService.recordPayment(payment);
                if (res['success'] == true) {
                  Navigator.pop(context, true);
                }
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadPayments();
      widget.onUpdate();
    }
  }
}
