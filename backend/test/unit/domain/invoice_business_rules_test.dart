import 'package:test/test.dart';
import 'package:fs_hub_backend/shared/domain/invoice_business_rules.dart';

void main() {
  group('InvoiceBusinessRules — create invoice', () {
    test('INVOICE requires timbre = 1 TND', () {
      expect(
        () => InvoiceBusinessRules.validateTimbreForType('INVOICE', 0.0),
        throwsA(isA<InvoiceRuleException>()),
      );
      expect(
        () => InvoiceBusinessRules.validateTimbreForType('INVOICE', 1.0),
        returnsNormally,
      );
    });

    test('DELIVERY_NOTE requires timbre = 0', () {
      expect(
        () => InvoiceBusinessRules.validateTimbreForType('DELIVERY_NOTE', 1.0),
        throwsA(isA<InvoiceRuleException>()),
      );
    });

    test('quote must be approved before invoicing', () {
      expect(
        () => InvoiceBusinessRules.validateQuoteApproved('Brouillon'),
        throwsA(isA<InvoiceRuleException>()),
      );
      expect(
        () => InvoiceBusinessRules.validateQuoteApproved('Accepté'),
        returnsNormally,
      );
    });

    test('montant_ttc must equal HT + TVA + timbre', () {
      expect(
        InvoiceBusinessRules.isTtcConsistent(
          montantHt: 1000,
          tva: 190,
          timbre: 1,
          montantTtc: 1191,
        ),
        isTrue,
      );
      expect(
        InvoiceBusinessRules.isTtcConsistent(
          montantHt: 1000,
          tva: 190,
          timbre: 1,
          montantTtc: 1200,
        ),
        isFalse,
      );
    });

    test('delivery note blocked when project not completed', () {
      expect(
        () => InvoiceBusinessRules.validateProjectForDeliveryNote('En cours'),
        throwsA(isA<InvoiceRuleException>()),
      );
      expect(
        () => InvoiceBusinessRules.validateProjectForDeliveryNote('Completed'),
        returnsNormally,
      );
    });
  });
}
