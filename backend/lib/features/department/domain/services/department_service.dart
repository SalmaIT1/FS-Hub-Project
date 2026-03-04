import '../../data/repositories/department_repository.dart';

class DepartmentService {
  static final _repository = DepartmentRepository();

  static Future<List<Map<String, dynamic>>> getAllDepartments() async {
    final depts = await _repository.getAllDepartments();
    return depts.map((d) => d.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getDepartmentById(String id) async {
    final dept = await _repository.getDepartmentById(id);
    return dept?.toJson();
  }

  static Future<void> createDepartment(Map<String, dynamic> data) async {
    await _repository.createDepartment(data);
  }

  static Future<void> updateDepartment(String id, Map<String, dynamic> data) async {
    await _repository.updateDepartment(id, data);
  }

  static Future<Map<String, dynamic>> deleteDepartment(String id) async {
    final count = await _repository.getEmployeeCount(id);
    if (count > 0) {
      return {'success': false, 'message': 'Cannot delete department: $count employees are still assigned to it.'};
    }
    await _repository.deleteDepartment(id);
    return {'success': true};
  }
}
