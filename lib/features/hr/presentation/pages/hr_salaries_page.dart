import 'package:flutter/material.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/salary_model.dart';
import 'package:intl/intl.dart';

class HrSalariesPage extends StatefulWidget {
  const HrSalariesPage({super.key});

  @override
  State<HrSalariesPage> createState() => _HrSalariesPageState();
}

class _HrSalariesPageState extends State<HrSalariesPage> {
  List<Salary> _salaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await HrService.getSalaries();
    if (mounted) setState(() { _salaries = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Salaries',
      showBackButton: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
              itemCount: _salaries.length,
              itemBuilder: (ctx, i) {
                final l = _salaries[i];
                return Card(
                  child: ListTile(
                     title: Text('${l.employeeId} - ${DateFormat.yMMMM().format(l.salaryMonth)}'),
                     subtitle: Text('Base: ${l.baseSalary} DH'),
                     trailing: Text(l.paymentStatus.toUpperCase(), style: TextStyle(
                      color: l.paymentStatus == 'paid' ? Colors.green : (l.paymentStatus == 'cancelled' ? Colors.red : Colors.orange),
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
