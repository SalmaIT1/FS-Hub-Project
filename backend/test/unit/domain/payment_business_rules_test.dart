import 'package:test/test.dart';
import 'package:fs_hub_backend/shared/domain/payment_business_rules.dart';

void main() {
  group('PaymentBusinessRules — payment validation', () {
    test('accepts partial payment within balance', () {
      expect(
        () => PaymentBusinessRules.validatePaymentAmount(
          paymentAmount: 500,
          invoiceTtc: 1000,
          alreadyPaid: 200,
        ),
        returnsNormally,
      );
    });

    test('rejects zero or negative amount', () {
      expect(
        () => PaymentBusinessRules.validatePaymentAmount(
          paymentAmount: 0,
          invoiceTtc: 1000,
          alreadyPaid: 0,
        ),
        throwsA(isA<PaymentRuleException>()),
      );
    });

    test('rejects overpayment beyond invoice balance', () {
      expect(
        () => PaymentBusinessRules.validatePaymentAmount(
          paymentAmount: 900,
          invoiceTtc: 1000,
          alreadyPaid: 200,
        ),
        throwsA(isA<PaymentRuleException>()),
      );
    });
  });
}
