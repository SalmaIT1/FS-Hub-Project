import 'package:flutter/material.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/bonus_model.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/services/auth_service.dart';

class HrBonusesPage extends StatefulWidget {
  const HrBonusesPage({super.key});

  @override
  State<HrBonusesPage> createState() => _HrBonusesPageState();
}

class _HrBonusesPageState extends State<HrBonusesPage> {
  List<Bonus> _bonuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      final data = await HrService.getBonuses(user['id']);
      if (mounted) setState(() { _bonuses = data; _isLoading = false; });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Bonuses',
      showBackButton: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
              itemCount: _bonuses.length,
              itemBuilder: (ctx, i) {
                final l = _bonuses[i];
                return Card(
                  child: ListTile(
                     title: Text('${l.bonusType.toUpperCase()} - ${l.amount} DH'),
                     subtitle: Text(l.reason ?? 'No reason provided'),
                     trailing: l.grantedDate != null ? Text(DateFormat.yMd().format(l.grantedDate!)) : const Text('-'),
                  ),
                );
              },
          )
        ),
      ),
    );
  }
}
