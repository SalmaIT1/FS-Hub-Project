/// Invoice / delivery-note business rules (unit-testable, no DB).
class InvoiceBusinessRules {
  InvoiceBusinessRules._();

  /// Timbre fiscal rules: INVOICE = 1 TND, DELIVERY_NOTE = 0.
  static void validateTimbreForType(String type, double timbre) {
    if (type == 'INVOICE' && timbre != 1.0) {
      throw InvoiceRuleException(
        'Invoice blocked: Timbre (1 TND) is mandatory.',
      );
    }
    if (type == 'DELIVERY_NOTE' && timbre != 0.0) {
      throw InvoiceRuleException(
        'Delivery note blocked: Timbre must be 0.',
      );
    }
  }

  /// Quote must be approved before invoicing.
  static void validateQuoteApproved(String? quoteStatus) {
    if (quoteStatus == null) return;
    final ok = quoteStatus == 'Accepté' || quoteStatus == 'Approved';
    if (!ok) {
      throw InvoiceRuleException(
        "Invoice blocked: Associated quote must be 'Accepté' (Approved).",
      );
    }
  }

  /// Delivery note requires completed project.
  static void validateProjectForDeliveryNote(String? projectStatus) {
    if (projectStatus == null) return;
    if (projectStatus != 'Completed' && projectStatus != 'Terminé') {
      throw InvoiceRuleException(
        'Delivery note blocked: Project must be completed.',
      );
    }
  }

  static double computeMontantTtc({
    required double montantHt,
    required double tva,
    required double timbre,
  }) =>
      montantHt + tva + timbre;

  /// Validates HT + TVA + timbre ≈ TTC (±epsilon).
  static bool isTtcConsistent({
    required double montantHt,
    required double tva,
    required double timbre,
    required double montantTtc,
    double epsilon = 0.02,
  }) {
    final expected = computeMontantTtc(
      montantHt: montantHt,
      tva: tva,
      timbre: timbre,
    );
    return (expected - montantTtc).abs() <= epsilon;
  }
}

class InvoiceRuleException implements Exception {
  final String message;
  InvoiceRuleException(this.message);
  @override
  String toString() => message;
}
