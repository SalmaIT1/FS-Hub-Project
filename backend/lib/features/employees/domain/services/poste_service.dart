import '../../data/models/poste_model.dart';
import '../../data/repositories/poste_repository.dart';

class PosteService {
  final PosteRepository _repository = PosteRepository();

  Future<List<PosteModel>> getAllPostes() {
    return _repository.getAllPostes();
  }

  Future<PosteModel?> getPosteById(int id) {
    return _repository.getPosteById(id);
  }

  Future<PosteModel?> getPosteByName(String name) {
    return _repository.getPosteByName(name);
  }

  Future<PosteModel> createPoste(PosteModel poste) {
    return _repository.createPoste(poste);
  }

  Future<PosteModel> updatePoste(PosteModel poste) {
    return _repository.updatePoste(poste);
  }

  Future<bool> deletePoste(int id) {
    return _repository.deletePoste(id);
  }

  Future<List<PosteModel>> searchPostes(String query) {
    return _repository.searchPostes(query);
  }

  Future<int> getPosteCount() {
    return _repository.getPosteCount();
  }

  Future<List<Map<String, dynamic>>> getPostesWithDetails() async {
    final postes = await getAllPostes();
    return postes.map((poste) => poste.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> getPostesByDepartment(int departmentId) async {
    final postes = await _repository.getPostesByDepartment(departmentId);
    return postes.map((poste) => poste.toJson()).toList();
  }

  Future<Map<String, dynamic>> createPosteFromJson(Map<String, dynamic> json) async {
    try {
      final poste = PosteModel(
        nom: json['nom'],
        description: json['description'],
      );

      final createdPoste = await createPoste(poste);
      
      return {
        'success': true,
        'message': 'Poste created successfully',
        'data': createdPoste.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create poste: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> updatePosteFromJson(int id, Map<String, dynamic> json) async {
    try {
      final poste = PosteModel(
        id: id,
        nom: json['nom'],
        description: json['description'],
      );

      final updatedPoste = await updatePoste(poste);
      
      return {
        'success': true,
        'message': 'Poste updated successfully',
        'data': updatedPoste.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update poste: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> deletePosteWithResponse(int id) async {
    try {
      final success = await deletePoste(id);
      return {
        'success': success,
        'message': success ? 'Poste deleted successfully' : 'Poste not found',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete poste: $e',
      };
    }
  }

  Future<Map<String, dynamic>> searchPostesWithResponse(String query) async {
    try {
      final postes = await searchPostes(query);
      return {
        'success': true,
        'data': postes.map((poste) => poste.toJson()).toList(),
        'message': 'Postes searched successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to search postes: $e',
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getPosteStats() async {
    try {
      final count = await getPosteCount();
      return {
        'success': true,
        'data': {
          'total_postes': count,
        },
        'message': 'Poste statistics retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to retrieve poste statistics: $e',
        'data': null,
      };
    }
  }
}
