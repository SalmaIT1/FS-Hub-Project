import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/features/ai/data/services/ai_service.dart' show AiService;

class AiDashboardPage extends StatefulWidget {
  const AiDashboardPage({super.key});

  @override
  State<AiDashboardPage> createState() => _AiDashboardPageState();
}

class _AiDashboardPageState extends State<AiDashboardPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _projectRisks;
  Map<String, dynamic>? _paymentBehavior;
  Map<String, dynamic>? _strategicInsights;
  Map<String, dynamic>? _completionForecasts;
  Map<String, dynamic>? _employeePerformance;
  Map<String, dynamic>? _expenseAnomalies;

  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait<Map<String, dynamic>?>([
        AiService.getProjectRisks(),
        AiService.getPaymentBehavior(),
        AiService.getStrategicInsights(),
        AiService.getCompletionForecasts(),
        AiService.getEmployeePerformance(),
        AiService.getExpenseAnomalies(),
      ]);

      if (mounted) {
        final errors = <String>[];
        for (final r in results) {
          if (r != null && r['_error'] == true) {
            final msg = r['message']?.toString();
            if (msg != null && msg.isNotEmpty) errors.add(msg);
          }
        }
        setState(() {
          _projectRisks = results[0]?['_error'] == true ? null : results[0];
          _paymentBehavior = results[1]?['_error'] == true ? null : results[1];
          _strategicInsights = results[2]?['_error'] == true ? null : results[2];
          _completionForecasts = results[3]?['_error'] == true ? null : results[3];
          _employeePerformance = results[4]?['_error'] == true ? null : results[4];
          _expenseAnomalies = results[5]?['_error'] == true ? null : results[5];
          _errorMessage =
              errors.length == results.length ? errors.firstOrNull : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Intelligence IA',
      showBackButton: true,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: _gold,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAiDisclaimer(),
                      const SizedBox(height: 16),
                      if (_errorMessage != null) ...[
                        _buildErrorBanner(_errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      _buildSectionHeader('Niveau de Risque par Projet', Icons.speed_rounded),
                      const SizedBox(height: 20),
                      _buildProjectRiskGauges(),
                      const SizedBox(height: 30),
                      
                      _buildSectionHeader('Comportement de Paiement Clients', Icons.account_balance_wallet_outlined),
                      const SizedBox(height: 15),
                      _buildPaymentBehaviorList(),
                      const SizedBox(height: 30),
                      
                      _buildSectionHeader('Recommandations Stratégiques', Icons.tips_and_updates_outlined),
                      const SizedBox(height: 15),
                      _buildStrategicInsights(),
                      const SizedBox(height: 30),

                      _buildSectionHeader('Prévisions de fin de projet', Icons.schedule_rounded),
                      const SizedBox(height: 15),
                      _buildCompletionForecasts(),
                      const SizedBox(height: 30),

                      _buildSectionHeader('Performance équipe', Icons.groups_outlined),
                      const SizedBox(height: 15),
                      _buildEmployeePerformance(),
                      const SizedBox(height: 30),

                      _buildSectionHeader('Anomalies de dépenses', Icons.warning_amber_rounded),
                      const SizedBox(height: 15),
                      _buildExpenseAnomalies(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAiDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.25)),
      ),
      child: const Text(
        'Indicateurs estimés par règles métier et historique FS-Hub. '
        'Ils complètent votre jugement — ne remplacent pas une décision humaine.',
        style: TextStyle(fontSize: 11, height: 1.4),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 24),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectRiskGauges() {
    final List predictions = _projectRisks?['predictions'] ?? [];
    if (predictions.isEmpty) return _buildEmptyCard('Aucune donnée de projet active.');

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: predictions.map((p) {
        final risk = double.tryParse(p['delay_probability'].toString()) ?? 0.0;
        final band = p['risk_band']?.toString() ?? '';
        final color = band == 'CRITICAL' || risk > 0.7
            ? Colors.red
            : (band == 'HIGH' || band == 'MEDIUM' || risk > 0.35
                ? Colors.orange
                : Colors.green);
        final label = band == 'CRITICAL' || risk > 0.7
            ? 'Retard Critique'
            : (band == 'HIGH' || band == 'MEDIUM' || risk > 0.35
                ? 'Risque Modéré'
                : 'Gestion Saine');

        return Container(
          width: 165,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              Text(
                p['project_name'] ?? 'Projet',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 30,
                        startDegreeOffset: 270,
                        sections: [
                          PieChartSectionData(
                            value: risk * 100,
                            color: color,
                            radius: 8,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: (1 - risk) * 100,
                            color: color.withOpacity(0.1),
                            radius: 8,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(risk * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (p['explanation']?['summary_fr'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  p['explanation']['summary_fr'].toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentBehaviorList() {
    final List scores = _paymentBehavior?['client_scores'] ?? [];
    if (scores.isEmpty) return _buildEmptyCard('Historique de paiement insuffisant.');

    return Column(
      children: scores.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getScoreColor(s['reliability_score']).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  s['reliability_score']?.toString() ?? '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: _getScoreColor(s['reliability_score']),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['client_name']?.toString() ?? 'Client Inconnu',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    'Retard moyen : ${s['avg_delay_days']} jours',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s['behavior_type']?.toString() ?? 'Stable',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _gold),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildStrategicInsights() {
    final List recommendations = _strategicInsights?['recommendations'] ?? [];
    if (recommendations.isEmpty) return _buildEmptyCard('Génération d\'insights en cours...');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recommendations.map((msg) => Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: _gold, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg.toString(),
                  style: const TextStyle(fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCompletionForecasts() {
    final List items = _completionForecasts?['forecasts'] ?? [];
    if (items.isEmpty) {
      return _buildEmptyCard('Aucune prévision disponible.');
    }
    return Column(
      children: items.map<Widget>((f) {
        final name = f['project_name']?.toString() ?? 'Projet';
        final days = f['estimated_days_remaining']?.toString() ?? '—';
        return _buildInsightTile(name, '$days jours restants estimés');
      }).toList(),
    );
  }

  Widget _buildEmployeePerformance() {
    final List items = _employeePerformance?['employees'] ?? [];
    if (items.isEmpty) {
      return _buildEmptyCard('Aucune donnée performance.');
    }
    return Column(
      children: items.map<Widget>((e) {
        final name = e['employee_name']?.toString() ?? 'Employé';
        final score = e['performance_score']?.toString() ?? '—';
        return _buildInsightTile(name, 'Score: $score');
      }).toList(),
    );
  }

  Widget _buildExpenseAnomalies() {
    final List items = _expenseAnomalies?['anomalies'] ?? [];
    if (items.isEmpty) {
      return _buildEmptyCard('Aucune anomalie détectée.');
    }
    return Column(
      children: items.take(10).map<Widget>((a) {
        final id = a['id']?.toString() ?? '';
        final amount = a['montant']?.toString() ?? a['amount']?.toString() ?? '';
        return _buildInsightTile('Dépense #$id', 'Montant: $amount');
      }).toList(),
    );
  }

  Widget _buildInsightTile(String title, String subtitle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Color _getScoreColor(dynamic score) {
    final s = score?.toString();
    switch (s) {
      case 'A': return Colors.green;
      case 'B': return Colors.blue;
      case 'C': return Colors.orange;
      case 'D': return Colors.red;
      default:  return Colors.grey;
    }
  }
}
