/// Project / client financial status rules (unit-testable).
class ProjectFinancialRules {
  ProjectFinancialRules._();

  static String financialStatus({
    required double totalExpenses,
    required double estimation,
  }) {
    if (estimation <= 0) return 'healthy';
    final ratio = (totalExpenses / estimation) * 100;
    if (totalExpenses > estimation) return 'over_budget';
    if (ratio > 80) return 'warning';
    if (ratio > 60) return 'caution';
    return 'healthy';
  }

  static String clientStatusFromPaymentRatio(double paymentRatio) {
    if (paymentRatio >= 95) return 'excellent';
    if (paymentRatio >= 80) return 'good';
    if (paymentRatio >= 60) return 'average';
    if (paymentRatio >= 40) return 'poor';
    return 'critical';
  }

  static String riskLevel({
    required double expenseRatio,
    required double remainingBudget,
  }) {
    if (expenseRatio > 100 || remainingBudget < 0) return 'critical';
    if (expenseRatio > 85) return 'high';
    if (expenseRatio > 70) return 'medium';
    if (expenseRatio > 50) return 'low';
    return 'minimal';
  }

  /// Project cannot start production before initial payment threshold.
  static bool canStartProject({
    required double paidAmount,
    required double requiredDeposit,
  }) =>
      paidAmount >= requiredDeposit;
}
