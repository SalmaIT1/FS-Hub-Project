import '../../data/repositories/project_repository.dart';
import '../../../../shared/services/audit_service.dart';
import '../../../../core/services/data_integrity_service.dart';
import '../../../../shared/domain/project_status.dart';
import '../../../finance/data/repositories/finance_repository.dart';

class ProjectService {
  static final _repository = ProjectRepository();

  static Future<List<Map<String, dynamic>>> getAllProjects({String? callerRole, String? callerId}) async {
    // FIX: Clients only see projects linked to their client_id, not all company projects
    if (callerRole == 'Client' && callerId != null) {
      final projects = await _repository.getProjectsByUserId(callerId);
      return projects.map((p) => p.toJson()).toList();
    }
    // FIX: Employees only see projects they are members of
    if (callerRole == 'Employé' && callerId != null) {
      final projects = await _repository.getProjectsByEmployeeId(callerId);
      return projects.map((p) => p.toJson()).toList();
    }
    
    final projects = await _repository.getAllProjects();
    return projects.map((p) => p.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getProjectById(int id, {String? callerRole, String? callerId}) async {
    final project = await _repository.getProjectById(id);
    if (project == null) return null;

    // RBAC: Admins, Managers, and RH see all
    if (callerRole == 'Admin' || callerRole == 'Manager' || callerRole == 'RH') {
      return project.toJson();
    }

    // RBAC: Clients only see their own projects
    if (callerRole == 'Client' && callerId != null) {
      final isOwner = await _repository.isClientOwner(id, callerId);
      return isOwner ? project.toJson() : null;
    }

    // RBAC: Employees (and Team Leads) only see projects they are members of
    if (callerId != null) {
      final isMember = await _repository.isMember(id, callerId);
      return isMember ? project.toJson() : null;
    }

    return null;
  }

  static Future<int> createProject(Map<String, dynamic> data, {String? callerId}) async {
    if (data.containsKey('statut')) {
      data['statut'] = ProjectStatus.validate(data['statut']?.toString());
    }

    // A project cannot start 'En cours' without members, and new projects 
    // haven't had members assigned yet.
    if (data['statut'] == ProjectStatus.enCours) {
      throw Exception('Un nouveau projet doit d’abord être planifié pour y ajouter des membres avant de passer "En cours".');
    }

    final id = await _repository.createProject(data);
    await AuditService.log(callerId ?? 'SYSTEM', 'PROJECT_CREATED', {
      'projectId': id,
      'projectName': data['nom'],
    });
    return id;
  }

  static Future<void> updateProject(int id, Map<String, dynamic> data, {String? callerId}) async {
    if (data.containsKey('statut')) {
      data['statut'] = ProjectStatus.validate(data['statut']?.toString());
    }

    if (data['statut'] == ProjectStatus.enCours || data['statut'] == 'Active') {
      final members = await _repository.getProjectMembers(id);
      if (members.isEmpty) {
        throw Exception('Impossible de démarrer le projet : aucun membre assigné.');
      }
      
      // Validation: 50% upfront payment check
      final financeRepo = FinanceRepository();
      final invoices = await financeRepo.getInvoicesByProject(id);
      double totalBilled = 0.0;
      double totalPaid = 0.0;
      for (var invoice in invoices) {
         totalBilled += invoice.montantTtc ?? 0.0;
         final payments = await financeRepo.getPaymentsByInvoice(invoice.id!);
         for (var p in payments) {
            totalPaid += p.montant ?? 0.0;
         }
      }

      double baselineAmount = totalBilled;
      if (baselineAmount <= 0) {
        // P0 FIX: If no invoices issued yet, check the most recent approved quote for this project
        final quotes = await financeRepo.getQuotesByProject(id);
        final approvedQuotes = quotes.where((q) => q.statut == 'Accepté' || q.statut == 'Approved').toList();
        if (approvedQuotes.isNotEmpty) {
           baselineAmount = approvedQuotes.first.montantTtc;
        }
      }

      if (baselineAmount > 0 && totalPaid < (baselineAmount * 0.5)) {
         throw Exception("50% upfront payment required to activate project. (Required: ${(baselineAmount * 0.5).toStringAsFixed(2)}, Paid: ${totalPaid.toStringAsFixed(2)})");
      }
    }

    await _repository.updateProject(id, data);
    if (callerId != null) {
      await AuditService.log(callerId, 'PROJECT_UPDATED', {
        'projectId': id,
        'projectName': data['nom'],
        'fields': data.keys.toList(),
      });
    }
  }

  static Future<Map<String, dynamic>> deleteProject(int id, {String? callerId}) async {
    if (await _repository.hasActiveSprints(id)) {
      return {'success': false, 'message': 'Cannot delete project with active sprints.'};
    }
    
    final project = await _repository.getProjectById(id);
    await _repository.deleteProject(id);

    if (callerId != null) {
      await AuditService.log(callerId, 'PROJECT_DELETED', {
        'projectId': id,
        'projectName': project?.nom,
      });
    }

    return {'success': true};
  }

  static Future<void> checkDeadlines() async {
    await DataIntegrityService.checkDeadlines();
  }

  static Future<List<Map<String, dynamic>>> getAvailableEmployees() async {
    return await _repository.getAvailableEmployees();
  }

  static Future<List<Map<String, dynamic>>> getProjectMembers(int projectId) async {
    final members = await _repository.getProjectMembers(projectId);
    return members.map((m) => m.toJson()).toList();
  }

  static Future<void> addProjectMember(int projectId, String employeeId, {String role = 'Employé'}) async {
    await _repository.addProjectMember(projectId, employeeId, role);
  }

  static Future<void> removeProjectMember(int projectId, String employeeId) async {
    await _repository.removeProjectMember(projectId, employeeId);
  }
}
