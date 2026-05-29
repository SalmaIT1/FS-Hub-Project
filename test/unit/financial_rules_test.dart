import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/core/domain/project_financial_rules.dart';

void main() {
  group('ProjectFinancialRules (Flutter)', () {
    test('dashboard financial status matches backend rules', () {
      expect(
        ProjectFinancialRules.financialStatus(
          totalExpenses: 9000,
          estimation: 10000,
        ),
        'warning',
      );
    });

    test('client payment ratio drives status label', () {
      expect(
        ProjectFinancialRules.clientStatusFromPaymentRatio(85),
        'good',
      );
      expect(
        ProjectFinancialRules.clientStatusFromPaymentRatio(10),
        'critical',
      );
    });

    test('risk level for profitability widget', () {
      expect(
        ProjectFinancialRules.riskLevel(
          expenseRatio: 90,
          remainingBudget: 500,
        ),
        'high',
      );
    });
  });
}
