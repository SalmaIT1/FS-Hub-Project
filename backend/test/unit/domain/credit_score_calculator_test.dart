import 'package:test/test.dart';
import 'package:fs_hub_backend/shared/domain/credit_score_calculator.dart';

void main() {
  group('CreditScoreCalculator', () {
    test('excellent client with on-time payments', () {
      final result = CreditScoreCalculator.scoreFromMetrics({
        'late_count': 0,
        'invoice_count': 10,
        'avg_delay_days': 0,
        'solde_du': 0,
      });
      expect(result['score'], greaterThanOrEqualTo(750));
      expect(result['rating'], 'Excellent');
    });

    test('poor client with late invoices and high balance', () {
      final result = CreditScoreCalculator.scoreFromMetrics({
        'late_count': 8,
        'invoice_count': 12,
        'avg_delay_days': 30,
        'solde_du': 50000,
      });
      expect(result['score'], lessThan(450));
      expect(result['rating'], 'Poor');
    });

    test('no invoice history defaults to neutral score', () {
      final result = CreditScoreCalculator.scoreFromMetrics({
        'late_count': 0,
        'invoice_count': 0,
        'avg_delay_days': 0,
        'solde_du': 0,
      });
      expect(result['score'], 500);
    });

    test('score is clamped between 0 and 850', () {
      final result = CreditScoreCalculator.scoreFromMetrics({
        'late_count': 100,
        'invoice_count': 50,
        'avg_delay_days': 200,
        'solde_du': 999999,
      });
      expect(result['score'], inInclusiveRange(0, 850));
    });
  });
}
