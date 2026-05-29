import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:fs_hub_backend/features/finance/data/models/finance_model.dart';
import 'package:fs_hub_backend/features/finance/domain/services/finance_service.dart';
import 'package:fs_hub_backend/features/project/data/models/project_model.dart';
import 'package:fs_hub_backend/shared/domain/invoice_business_rules.dart';
import '../../mocks/repository_mocks.dart';

void main() {
  late MockFinanceRepository financeRepo;
  late MockProjectRepository projectRepo;

  setUpAll(registerRepositoryFallbacks);

  setUp(() {
    financeRepo = MockFinanceRepository();
    projectRepo = MockProjectRepository();
    FinanceService.bindForTest(finance: financeRepo, project: projectRepo);
  });

  tearDown(FinanceService.resetBindings);

  group('FinanceService.createInvoice', () {
    test('creates invoice with approved quote and timbre 1', () async {
      when(() => financeRepo.getQuoteById(10)).thenAnswer(
        (_) async => QuoteModel(
          id: 10,
          clientId: 5,
          projectId: 2,
          numeroDevis: 'DEV-001',
          statut: 'Accepté',
          montantHt: 1000,
          tva: 190,
          montantTtc: 1191,
        ),
      );
      when(() => financeRepo.createInvoice(any())).thenAnswer((_) async {});

      await FinanceService.createInvoice({
        'type': 'INVOICE',
        'quote_id': 10,
        'numero_facture': 'FAC-001',
        'timbre': 1,
      });

      final captured = verify(() => financeRepo.createInvoice(captureAny())).captured.single
          as Map<String, dynamic>;
      expect(captured['client_id'], 5);
      expect(captured['montant_ttc'], 1191);
      expect(captured['timbre'], 1.0);
    });

    test('blocks invoice when timbre is not 1 TND', () async {
      await expectLater(
        FinanceService.createInvoice({
          'type': 'INVOICE',
          'numero_facture': 'FAC-002',
          'timbre': 0,
        }),
        throwsA(isA<InvoiceRuleException>()),
      );
      verifyNever(() => financeRepo.createInvoice(any()));
    });

    test('blocks invoice when quote is not approved', () async {
      when(() => financeRepo.getQuoteById(11)).thenAnswer(
        (_) async => QuoteModel(
          id: 11,
          clientId: 1,
          numeroDevis: 'DEV-002',
          statut: 'Brouillon',
        ),
      );

      await expectLater(
        FinanceService.createInvoice({
          'type': 'INVOICE',
          'quote_id': 11,
          'timbre': 1,
        }),
        throwsA(isA<InvoiceRuleException>()),
      );
      verifyNever(() => financeRepo.createInvoice(any()));
    });

    test('blocks delivery note when project is not completed', () async {
      when(() => projectRepo.getProjectById(3)).thenAnswer(
        (_) async => ProjectModel(id: 3, nom: 'P1', statut: 'En cours'),
      );

      await expectLater(
        FinanceService.createInvoice({
          'type': 'DELIVERY_NOTE',
          'projet_id': 3,
          'numero_facture': 'BL-001',
          'timbre': 0,
        }),
        throwsA(isA<InvoiceRuleException>()),
      );
      verifyNever(() => financeRepo.createInvoice(any()));
    });

    test('creates delivery note for completed project', () async {
      when(() => projectRepo.getProjectById(3)).thenAnswer(
        (_) async => ProjectModel(id: 3, nom: 'P1', statut: 'Completed'),
      );
      when(() => financeRepo.createInvoice(any())).thenAnswer((_) async {});

      await FinanceService.createInvoice({
        'type': 'DELIVERY_NOTE',
        'projet_id': 3,
        'numero_facture': 'BL-002',
        'timbre': 0,
      });

      verify(() => financeRepo.createInvoice(any())).called(1);
    });
  });
}
