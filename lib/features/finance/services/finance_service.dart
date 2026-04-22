import 'dart:convert';
import 'package:fs_hub/shared/models/finance_model.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';

class FinanceService {
  static const String _endpoint = '/finance';

  static Future<List<Invoice>> getAllInvoices() async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/invoices',
        'GET',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          return data.map((json) => Invoice.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching invoices: $e');
      return [];
    }
  }

  static Future<List<Invoice>> getMyInvoices() async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/invoices/mine',
        'GET',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          return data.map((json) => Invoice.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching personal invoices: $e');
      return [];
    }
  }

  static Future<List<Invoice>> getInvoicesByProject(int projectId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/invoices/project/$projectId',
        'GET',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          return data.map((json) => Invoice.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching project invoices: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createInvoice(Invoice invoice) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/invoices',
        'POST',
        body: invoice.toJson(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateInvoice(Invoice invoice) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/invoices/${invoice.id}',
        'PUT',
        body: invoice.toJson(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteInvoice(int id) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/invoices/$id',
        'DELETE',
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // PAYMENTS
  static Future<List<Payment>> getPaymentsByInvoice(int invoiceId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/payments/invoice/$invoiceId',
        'GET',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          return data.map((json) => Payment.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching payments: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> recordPayment(Payment payment) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/payments',
        'POST',
        body: payment.toJson(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getFinanceSummary() async {
    try {
      final response = await AuthService.authenticatedRequest('$_endpoint/summary', 'GET');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error in getFinanceSummary: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getMyFinanceSummary() async {
    try {
      final response = await AuthService.authenticatedRequest('$_endpoint/summary/mine', 'GET');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'];
        }
      }
      return {};
    } catch (e) {
      print('Error in getMyFinanceSummary: $e');
      return {};
    }
  }

  // QUOTES (DEVIS)
  static Future<List<Quote>> getMyQuotes() async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/quotes/mine',
        'GET',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          return data.map((json) => Quote.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching personal quotes: $e');
      return [];
    }
  }

  static Future<List<Quote>> getQuotesByClient(int clientId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/quotes/client/$clientId',
        'GET',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          return data.map((json) => Quote.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching quotes: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> approveQuote(int quoteId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '$_endpoint/quotes/$quoteId/approve',
        'POST',
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
