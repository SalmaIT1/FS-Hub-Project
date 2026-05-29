import 'package:test/test.dart';
import 'package:fs_hub_backend/shared/domain/project_financial_rules.dart';

void main() {
  group('ProjectFinancialRules', () {
    test('financial status transitions', () {
      expect(
        ProjectFinancialRules.financialStatus(
          totalExpenses: 5000,
          estimation: 10000,
        ),
        'healthy',
      );
      expect(
        ProjectFinancialRules.financialStatus(
          totalExpenses: 6500,
          estimation: 10000,
        ),
        'caution',
      );
      expect(
        ProjectFinancialRules.financialStatus(
          totalExpenses: 8500,
          estimation: 10000,
        ),
        'warning',
      );
      expect(
        ProjectFinancialRules.financialStatus(
          totalExpenses: 12000,
          estimation: 10000,
        ),
        'over_budget',
      );
    });

    test('project cannot start before deposit paid', () {
      expect(
        ProjectFinancialRules.canStartProject(
          paidAmount: 0,
          requiredDeposit: 5000,
        ),
        isFalse,
      );
      expect(
        ProjectFinancialRules.canStartProject(
          paidAmount: 5000,
          requiredDeposit: 5000,
        ),
        isTrue,
      );
    });

    test('client credit status from payment ratio', () {
      expect(
        ProjectFinancialRules.clientStatusFromPaymentRatio(96),
        'excellent',
      );
      expect(
        ProjectFinancialRules.clientStatusFromPaymentRatio(30),
        'critical',
      );
    });

    test('risk level from expense ratio', () {
      expect(
        ProjectFinancialRules.riskLevel(
          expenseRatio: 110,
          remainingBudget: -100,
        ),
        'critical',
      );
      expect(
        ProjectFinancialRules.riskLevel(
          expenseRatio: 40,
          remainingBudget: 6000,
        ),
        'minimal',
      );
    });
  });
}
