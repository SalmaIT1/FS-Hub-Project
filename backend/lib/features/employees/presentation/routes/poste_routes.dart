import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/poste_service.dart';
import '../../../../core/middleware/permission_middleware.dart';

class PosteRoutes {
  final PosteService _posteService = PosteService();
  final Router _router = Router();

  PosteRoutes() {
    _setupRoutes();
  }

  void _setupRoutes() {
    _router.get('/', Pipeline().addMiddleware(requirePermission('view_employees')).addHandler(_getAllPostes));
    _router.get('/search', Pipeline().addMiddleware(requirePermission('view_employees')).addHandler(_searchPostes));
    _router.get('/stats', Pipeline().addMiddleware(requirePermission('view_employees')).addHandler(_getPosteStats));
    _router.get('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('view_employees')).addHandler((req) => _getPosteById(req, id))(request));
    _router.post('/', Pipeline().addMiddleware(requirePermission('manage_system')).addHandler(_createPoste));
    _router.put('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_system')).addHandler((req) => _updatePoste(req, id))(request));
    _router.delete('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_system')).addHandler((req) => _deletePoste(req, id))(request));
  }

  Future<Response> _getAllPostes(Request request) async {
    try {
      final deptIdParam = request.url.queryParameters['departement_id'];
      List<Map<String, dynamic>> postes;

      if (deptIdParam != null) {
        final deptId = int.tryParse(deptIdParam);
        if (deptId == null) {
          return Response(400, body: jsonEncode({'success': false, 'message': 'Invalid departement_id'}), headers: {'content-type': 'application/json; charset=utf-8'});
        }
        postes = await _posteService.getPostesByDepartment(deptId);
      } else {
        postes = await _posteService.getPostesWithDetails();
      }
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': postes,
          'message': 'Postes retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e, stackTrace) {
      print('Exception in _getAllPostes: $e\n$stackTrace');
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Internal server error',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getPosteById(Request request, String id) async {
    try {
      final posteId = int.parse(id);
      final poste = await _posteService.getPosteById(posteId);
      
      if (poste == null) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'Poste not found',
          }),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': poste.toJson(),
          'message': 'Poste retrieved successfully',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Internal server error',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _createPoste(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _posteService.createPosteFromJson(json);
      
      return Response(
        result['success'] ? 201 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Internal server error',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _updatePoste(Request request, String id) async {
    try {
      final posteId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _posteService.updatePosteFromJson(posteId, json);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Internal server error',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _deletePoste(Request request, String id) async {
    try {
      final posteId = int.parse(id);
      final result = await _posteService.deletePosteWithResponse(posteId);
      
      return Response(
        result['success'] ? 200 : 404,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Internal server error',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _searchPostes(Request request) async {
    try {
      final query = request.url.queryParameters['q'] ?? '';
      if (query.isEmpty) {
        return Response(400, body: jsonEncode({
          'success': false,
          'message': 'Search query parameter "q" is required',
        }), headers: {'content-type': 'application/json; charset=utf-8'});
      }
      
      final result = await _posteService.searchPostesWithResponse(query);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Internal server error',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _getPosteStats(Request request) async {
    try {
      final result = await _posteService.getPosteStats();
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Internal server error',
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Router get router {
    return _router;
  }
}
