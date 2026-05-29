/// Payment validation rules (unit-testable).
class PaymentBusinessRules {
  PaymentBusinessRules._();

  static const double overpaymentEpsilon = 0.001;

  static void validatePaymentAmount({
    required double paymentAmount,
    required double invoiceTtc,
    required double alreadyPaid,
  }) {
    if (paymentAmount <= 0) {
      throw PaymentRuleException('Payment amount must be positive');
    }
    final remaining = invoiceTtc - alreadyPaid;
    if (paymentAmount > remaining + overpaymentEpsilon) {
      throw PaymentRuleException(
        'Overpayment Error: Payment ($paymentAmount) exceeds balance ($remaining). '
        'Invoice total: $invoiceTtc, paid: $alreadyPaid.',
      );
    }
  }
}

class PaymentRuleException implements Exception {
  final String message;
  PaymentRuleException(this.message);
  @override
  String toString() => message;
}
