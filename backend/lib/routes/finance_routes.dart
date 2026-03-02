import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';

class FinanceRoutes {
  late final Router router;

  FinanceRoutes() {
    router = Router()
      // Invoices
      ..get('/invoices', _getAllInvoices)
      ..get('/invoices/project/<projectId>', _getInvoicesByProject)
      ..get('/invoices/<id>', _getInvoiceById)
      ..post('/invoices', _createInvoice)
      ..put('/invoices/<id>', _updateInvoice)
      ..delete('/invoices/<id>', _deleteInvoice)
      
      // Summary
      ..get('/summary', _getFinanceSummary)
      
      // Payments
      ..get('/payments/invoice/<invoiceId>', _getPaymentsByInvoice)
      ..post('/payments', _createPayment)
      ..delete('/payments/<id>', _deletePayment);
  }

  Future<Response> _getFinanceSummary(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      
      final billedRes = await conn.execute('SELECT SUM(montant_ttc) as total FROM factures');
      final paidRes = await conn.execute('SELECT SUM(montant) as total FROM paiements');
      
      final statusRes = await conn.execute('SELECT statut, COUNT(*) as count, SUM(montant_ttc) as amount FROM factures GROUP BY statut');
      
      final billed = double.tryParse(billedRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
      final paid = double.tryParse(paidRes.rows.first.assoc()['total']?.toString() ?? '0') ?? 0.0;
      
      final statusDistribution = statusRes.rows.map((row) => row.assoc()).toList();

      return Response.ok(jsonEncode({
        'total_billed': billed,
        'total_paid': paid,
        'outstanding': billed - paid,
        'status_distribution': statusDistribution,
      }), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // INVOICES
  Future<Response> _getAllInvoices(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      final result = await conn.execute('''
        SELECT f.*, p.nom as project_nom 
        FROM factures f
        LEFT JOIN projets p ON f.projet_id = p.id
        ORDER BY f.date_emission DESC
      ''');
      final invoices = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(invoices), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getInvoicesByProject(Request request) async {
    try {
      final projectId = request.params['projectId'];
      final conn = DBConnection.getConnection();
      final result = await conn.execute('SELECT * FROM factures WHERE projet_id = :pid', {'pid': projectId});
      final invoices = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(invoices), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getInvoiceById(Request request) async {
    try {
      final id = request.params['id'];
      final conn = DBConnection.getConnection();
      final result = await conn.execute('SELECT * FROM factures WHERE id = :id', {'id': id});
      if (result.rows.isEmpty) return Response.notFound(jsonEncode({'error': 'Invoice not found'}));
      return Response.ok(jsonEncode(result.rows.first.assoc()), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _createInvoice(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        INSERT INTO factures (projet_id, client_id, numero_facture, montant_ht, tva, montant_ttc, date_emission, date_echeance, statut)
        VALUES (:pid, :cid, :num, :ht, :tva, :ttc, :em, :ec, :stat)
      ''', {
        'pid': data['projet_id'],
        'cid': data['client_id'],
        'num': data['numero_facture'],
        'ht': data['montant_ht'],
        'tva': data['tva'],
        'ttc': data['montant_ttc'],
        'em': data['date_emission'],
        'ec': data['date_echeance'],
        'stat': data['statut'] ?? 'Brouillon',
      });

      return Response(201, body: jsonEncode({'success': true, 'message': 'Invoice created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _updateInvoice(Request request) async {
    try {
      final id = request.params['id'];
      final data = jsonDecode(await request.readAsString());
      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        UPDATE factures SET 
          numero_facture = :num, montant_ht = :ht, tva = :tva, 
          montant_ttc = :ttc, date_emission = :em, date_echeance = :ec, statut = :stat
        WHERE id = :id
      ''', {
        'id': id,
        'num': data['numero_facture'],
        'ht': data['montant_ht'],
        'tva': data['tva'],
        'ttc': data['montant_ttc'],
        'em': data['date_emission'],
        'ec': data['date_echeance'],
        'stat': data['statut'],
      });

      return Response.ok(jsonEncode({'success': true, 'message': 'Invoice updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _deleteInvoice(Request request) async {
    try {
      final id = request.params['id'];
      final conn = DBConnection.getConnection();
      await conn.execute('DELETE FROM factures WHERE id = :id', {'id': id});
      return Response.ok(jsonEncode({'success': true, 'message': 'Invoice deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // PAYMENTS
  Future<Response> _getPaymentsByInvoice(Request request) async {
    try {
      final invoiceId = request.params['invoiceId'];
      final conn = DBConnection.getConnection();
      final result = await conn.execute('SELECT * FROM paiements WHERE facture_id = :fid', {'fid': invoiceId});
      final payments = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(payments), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _createPayment(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        INSERT INTO paiements (facture_id, montant, mode, date_paiement, reference_transaction)
        VALUES (:fid, :mnt, :mode, :date, :ref)
      ''', {
        'fid': data['facture_id'],
        'mnt': data['montant'],
        'mode': data['mode'],
        'date': data['date_paiement'],
        'ref': data['reference_transaction'],
      });

      // Optionally update invoice status if fully paid
      // This logic could be more complex but let's keep it simple for now

      return Response(201, body: jsonEncode({'success': true, 'message': 'Payment recorded'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _deletePayment(Request request) async {
    try {
      final id = request.params['id'];
      final conn = DBConnection.getConnection();
      await conn.execute('DELETE FROM paiements WHERE id = :id', {'id': id});
      return Response.ok(jsonEncode({'success': true, 'message': 'Payment deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}
