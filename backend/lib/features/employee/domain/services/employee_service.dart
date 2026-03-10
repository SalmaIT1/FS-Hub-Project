import 'package:bcrypt/bcrypt.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/models/employee_model.dart';
import '../../../../shared/services/audit_service.dart';

class EmployeeService {
  static final _repository = EmployeeRepository();

  static const allowedRoles = {'Admin', 'Manager', 'Employé', 'RH', 'Team Lead', 'Comptable', 'Client'};
  static const allowedStatuts = {'actif', 'inactif', 'suspendu'};

  static Future<Map<String, dynamic>> getAllEmployees({int page = 1, int limit = 50}) async {
    final offset = (page - 1) * limit;
    final res = await _repository.getAllEmployees(limit: limit, offset: offset);
    
    final employees = (res['employees'] as List).cast<EmployeeModel>();
    final total = res['total'] as int;

    return {
      'success': true,
      'data': employees.map((e) => e.toJson()).toList(),
      'pagination': {
        'page': page,
        'limit': limit,
        'total': total,
        'pages': (total / limit).ceil(),
      }
    };
  }

  static Future<Map<String, dynamic>> getEmployeeById(String id) async {
    final emp = await _repository.getEmployeeById(id);
    if (emp == null) return {'success': false, 'message': 'Employee not found'};
    return {'success': true, 'data': emp.toJson()};
  }

  static Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data, {String? callerId}) async {
    final requiredFields = ['nom', 'prenom', 'email', 'username', 'password'];
    for (final f in requiredFields) {
      if (data[f] == null || data[f].toString().trim().isEmpty) {
        return {'success': false, 'message': 'Field "$f" is required'};
      }
    }

    String role = data['role']?.toString() ?? 'Employé';
    
    if (!allowedRoles.contains(role)) return {'success': false, 'message': 'Invalid role: $role'};
    data['role'] = role;

    final hashedPassword = BCrypt.hashpw(data['password'].toString(), BCrypt.gensalt());
    data['hashedPassword'] = hashedPassword;

    try {
      final id = await _repository.createEmployee(data);
      await AuditService.log(callerId ?? 'SYSTEM', 'EMPLOYEE_CREATED', {
        'employeeId': id,
        'username': data['username'],
        'role': role,
      });
      return {'success': true, 'message': 'Employee created successfully', 'data': {'id': id}};
    } catch (e) {
      return {'success': false, 'message': e.toString().contains('already exists') ? e.toString() : 'Failed to create employee'};
    }
  }

  static Future<Map<String, dynamic>> updateEmployee(String id, Map<String, dynamic> data, {required String callerRole, required String callerId}) async {
    final existing = await _repository.getEmployeeById(id);
    if (existing == null) return {'success': false, 'message': 'Employee not found'};

    if (callerRole != 'Admin' && callerRole != 'RH' && callerId != id) {
      return {'success': false, 'message': 'Permission denied'};
    }

    bool canChangeAdminFields = (callerRole == 'Admin' || callerRole == 'RH');
    
    final updateData = {
      'matricule': canChangeAdminFields ? (data['matricule'] ?? existing.matricule) : existing.matricule,
      'nom': data['nom'] ?? existing.nom,
      'prenom': data['prenom'] ?? existing.prenom,
      'dateNaissance': data['dateNaissance'] ?? existing.dateNaissance,
      'sexe': data['sexe'] ?? existing.sexe,
      'photo': data['photo'] ?? existing.photo,
      'email': data['email'] ?? existing.email,
      'telephone': data['telephone'] ?? existing.telephone,
      'adresse': data['adresse'] ?? existing.adresse,
      'ville': data['ville'] ?? existing.ville,
      'poste': canChangeAdminFields ? (data['poste'] ?? existing.poste) : existing.poste,
      'departement': canChangeAdminFields ? (data['departement'] ?? existing.departement) : existing.departement,
      'dateEmbauche': data['dateEmbauche'] ?? existing.dateEmbauche,
      'typeContrat': data['typeContrat'] ?? existing.typeContrat,
      'statut': canChangeAdminFields ? (data['statut'] ?? existing.statut) : existing.statut,
    };

    await _repository.updateEmployee(id, updateData);
    await AuditService.log(callerId, 'EMPLOYEE_UPDATED', {
      'targetEmployeeId': id,
      'fields': data.keys.toList(),
    });
    return {'success': true, 'message': 'Employee updated successfully'};
  }

  static Future<Map<String, dynamic>> deactivateEmployee(String id, {required String callerRole, String? callerId}) async {
    if (callerRole != 'Admin') return {'success': false, 'message': 'Admin role required'};

    final existing = await _repository.getEmployeeById(id);
    if (existing == null) return {'success': false, 'message': 'Employee not found'};

    await _repository.deactivateEmployee(id, existing.userId);
    await AuditService.log(callerId ?? 'SYSTEM', 'EMPLOYEE_DEACTIVATED', {
      'employeeId': id,
      'userId': existing.userId,
    });
    return {'success': true, 'message': 'Employee deactivated successfully'};
  }

  static String _mapPosteToRole(String? poste) {
    if (poste == null) return 'Employé';
    final p = poste.toLowerCase();
    
    if (p.contains('rh') || p.contains('ressources humaines') || p.contains('recrutement')) {
      return 'RH';
    }
    // Admin should NEVER be assigned automatically via title for security.
    // It must be explicitly set by an existing administrator.
    
    if (p.contains('comptable') || p.contains('finance') || p.contains('tresorier') || p.contains('compta')) {
      return 'Comptable';
    }
    if (p.contains('manager') || p.contains('chef de departement') || p.contains('directeur adjoint')) {
      return 'Manager';
    }
    if (p.contains('chef de projet') || p.contains('team lead') || p.contains('lead')) {
      return 'Team Lead';
    }
    if (p.contains('client') || p.contains('partenaire')) {
      return 'Client';
    }
    
    return 'Employé';
  }
}
