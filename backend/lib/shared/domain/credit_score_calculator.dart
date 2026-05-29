/// Pure credit-score calculation from client payment metrics (unit-testable).
class CreditScoreCalculator {
  CreditScoreCalculator._();

  static Map<String, dynamic> scoreFromMetrics(Map<String, dynamic> metrics) {
    final lateCount =
        int.tryParse(metrics['late_count']?.toString() ?? '0') ?? 0;
    final invoiceCount =
        int.tryParse(metrics['invoice_count']?.toString() ?? '0') ?? 0;
    final avgDelay =
        double.tryParse(metrics['avg_delay_days']?.toString() ?? '0') ?? 0;
    final solde =
        double.tryParse(metrics['solde_du']?.toString() ?? '0') ?? 0;

    var score = 850.0;
    score -= lateCount * 45;
    score -= avgDelay * 2;
    score -= (solde / 1000).clamp(0, 200);
    if (invoiceCount == 0) score = 500;
    score = score.clamp(0, 850);

    final rating = _ratingForScore(score);

    return {
      'score': score.round(),
      'rating': rating,
      'late_invoices': lateCount,
      'invoice_count': invoiceCount,
      'avg_delay_days': avgDelay.round(),
      'outstanding_balance': solde,
    };
  }

  static String _ratingForScore(double score) {
    if (score >= 750) return 'Excellent';
    if (score >= 600) return 'Good';
    if (score >= 450) return 'Fair';
    return 'Poor';
  }
}
