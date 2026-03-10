import 'package:flutter/material.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/remote_work_model.dart';
import 'package:intl/intl.dart';

class HrRemoteWorkPage extends StatefulWidget {
  const HrRemoteWorkPage({super.key});

  @override
  State<HrRemoteWorkPage> createState() => _HrRemoteWorkPageState();
}

class _HrRemoteWorkPageState extends State<HrRemoteWorkPage> {
  List<RemoteWork> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await HrService.getRemoteWorkRequests();
    if (mounted) setState(() { _requests = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Remote Work',
      showBackButton: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (ctx, i) {
                final l = _requests[i];
                return Card(
                  child: ListTile(
                     title: Text('${l.type.toUpperCase()} - ${l.employeeId}'),
                     subtitle: Text(DateFormat.yMMMMEEEEd().format(l.remoteDate)),
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
