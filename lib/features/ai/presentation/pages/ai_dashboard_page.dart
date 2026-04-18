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
  Map<String, dynamic>? _projectRisks;
  Map<String, dynamic>? _paymentBehavior;
  Map<String, dynamic>? _strategicInsights;

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
      ]);

      if (mounted) {
        setState(() {
          _projectRisks = results[0];
          _paymentBehavior = results[1];
          _strategicInsights = results[2];
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
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
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
        final color = risk > 0.7 ? Colors.red : (risk > 0.35 ? Colors.orange : Colors.green);
        final label = risk > 0.7 ? 'Retard Critique' : (risk > 0.35 ? 'Risque Modéré' : 'Gestion Saine');

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
