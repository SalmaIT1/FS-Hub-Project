import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';
import '../../../notification/domain/services/notification_service.dart';
import '../../../../shared/services/audit_service.dart';

class ExpenseService {
  final ExpenseRepository _repository = ExpenseRepository();

  // Project expenses
  Future<List<ExpenseModel>> getAllProjectExpenses({int? projectId}) {
    return _repository.getAllProjectExpenses(projectId: projectId);
  }

  Future<ExpenseModel?> getProjectExpenseById(int id) {
    return _repository.getProjectExpenseById(id);
  }

  Future<ExpenseModel> createProjectExpense(ExpenseModel expense) {
    return _repository.createProjectExpense(expense);
  }

  Future<ExpenseModel> updateProjectExpense(ExpenseModel expense) {
    return _repository.updateProjectExpense(expense);
  }

  Future<bool> deleteProjectExpense(int id) {
    return _repository.deleteProjectExpense(id);
  }

  // Company expenses
  Future<List<ExpenseModel>> getAllCompanyExpenses() {
    return _repository.getAllCompanyExpenses();
  }

  Future<ExpenseModel?> getCompanyExpenseById(int id) {
    return _repository.getCompanyExpenseById(id);
  }

  Future<ExpenseModel> createCompanyExpense(ExpenseModel expense) {
    return _repository.createCompanyExpense(expense);
  }

  Future<ExpenseModel> updateCompanyExpense(ExpenseModel expense) {
    return _repository.updateCompanyExpense(expense);
  }

  Future<bool> deleteCompanyExpense(int id) {
    return _repository.deleteCompanyExpense(id);
  }

  // Categories
  Future<List<ExpenseCategoryModel>> getExpenseCategories() {
    return _repository.getAllExpenseCategories();
  }

  Future<ExpenseCategoryModel> createExpenseCategory(ExpenseCategoryModel category) {
    return _repository.createExpenseCategory(category);
  }

  // Aliases for routes
  Future<List<ExpenseCategoryModel>> getCompanyExpenseCategories() => getExpenseCategories();
  Future<ExpenseCategoryModel> createCompanyExpenseCategory(ExpenseCategoryModel category) => createExpenseCategory(category);

  // Summaries
  Future<Map<String, dynamic>> getProjectExpenseSummary({int? projectId}) {
    return _repository.getProjectExpenseSummary(projectId: projectId);
  }

  Future<Map<String, dynamic>> getCompanyExpenseSummary() {
    return _repository.getCompanyExpenseSummary();
  }

  // Utility methods
  Future<List<Map<String, dynamic>>> getProjectExpensesWithDetails({int? projectId}) async {
    final expenses = await getAllProjectExpenses(projectId: projectId);
    return expenses.map((expense) => expense.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> getCompanyExpensesWithDetails() async {
    final expenses = await getAllCompanyExpenses();
    return expenses.map((expense) => expense.toJson()).toList();
  }

  Future<Map<String, dynamic>> createProjectExpenseFromJson(Map<String, dynamic> json) async {
    try {
      final expense = ExpenseModel(
        categorie: json['categorie'] ?? '',
        montant: (json['montant'] as num).toDouble(),
        dateDepense: DateTime.parse(json['date_depense']),
        description: json['description'],
        projectId: json['projet_id'],
        categoryId: json['category_id'],
        createdBy: json['created_by'],
      );

      final createdExpense = await createProjectExpense(expense);
      
      await AuditService.log(json['created_by']?.toString() ?? 'SYSTEM', 'PROJECT_EXPENSE_CREATED', {
        'expenseId': createdExpense.id,
        'montant': createdExpense.montant,
        'projectId': createdExpense.projectId,
      });

      return {
        'success': true,
        'message': 'Project expense created successfully',
        'data': createdExpense.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create project expense: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> createCompanyExpenseFromJson(Map<String, dynamic> json) async {
    try {
      final expense = ExpenseModel(
        categorie: json['categorie'] ?? '',
        montant: (json['montant'] as num).toDouble(),
        dateDepense: DateTime.parse(json['date_depense']),
        description: json['description'],
        categoryId: json['category_id'],
        createdBy: json['created_by'],
      );

      final createdExpense = await createCompanyExpense(expense);
      
      await AuditService.log(json['created_by']?.toString() ?? 'SYSTEM', 'COMPANY_EXPENSE_CREATED', {
        'expenseId': createdExpense.id,
        'montant': createdExpense.montant,
      });

      return {
        'success': true,
        'message': 'Company expense created successfully',
        'data': createdExpense.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create company expense: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> updateProjectExpenseFromJson(int id, Map<String, dynamic> json) async {
    try {
      final expense = ExpenseModel(
        id: id,
        categorie: json['categorie'] ?? '',
        montant: (json['montant'] as num).toDouble(),
        dateDepense: DateTime.parse(json['date_depense']),
        description: json['description'],
        projectId: json['projet_id'],
        categoryId: json['category_id'],
      );

      final updatedExpense = await updateProjectExpense(expense);
      return {
        'success': true,
        'message': 'Project expense updated successfully',
        'data': updatedExpense.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update project expense: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> updateCompanyExpenseFromJson(int id, Map<String, dynamic> json) async {
    try {
      final expense = ExpenseModel(
        id: id,
        categorie: json['categorie'] ?? '',
        montant: (json['montant'] as num).toDouble(),
        dateDepense: DateTime.parse(json['date_depense']),
        description: json['description'],
        categoryId: json['category_id'],
      );

      final updatedExpense = await updateCompanyExpense(expense);
      return {
        'success': true,
        'message': 'Company expense updated successfully',
        'data': updatedExpense.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update company expense: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> deleteProjectExpenseWithResponse(int id) async {
    try {
      final success = await deleteProjectExpense(id);
      return {
        'success': success,
        'message': success ? 'Project expense deleted successfully' : 'Project expense not found',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete project expense: $e',
      };
    }
  }

  Future<Map<String, dynamic>> deleteCompanyExpenseWithResponse(int id) async {
    try {
      final success = await deleteCompanyExpense(id);
      return {
        'success': success,
        'message': success ? 'Company expense deleted successfully' : 'Company expense not found',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete company expense: $e',
      };
    }
  }

  Future<Map<String, dynamic>> approveExpense(String type, int id, String userId, String role) async {
    try {
      final expense = type == 'project' 
          ? await getProjectExpenseById(id) 
          : await getCompanyExpenseById(id);
      
      if (expense == null) return {'success': false, 'message': 'Expense not found'};

      // Safety check: Cannot approve your own expense - even for Admins, for audit integrity.
      if (expense.createdBy == userId) {
        return {'success': false, 'message': 'You cannot approve your own expense request.'};
      }

      String newStatus = '';
      String step = '';

      if (role == 'Manager' && expense.status == 'pending') {
        newStatus = 'approved_manager';
        step = 'manager';
      } else if (role == 'RH' && expense.status == 'approved_manager') {
        newStatus = 'approved_hr';
        step = 'hr';
      } else if (role == 'Comptable' && expense.status == 'approved_hr') {
        newStatus = 'approved_finance';
        step = 'finance';
      } else if (role == 'Admin') {
        // Admin can skip or finalize anything
        newStatus = 'approved_finance';
        step = 'finance';
      } else {
        return {'success': false, 'message': 'Invalid approval sequence or unauthorized role'};
      }

      await _repository.updateExpenseStatus(type, id, newStatus, userId, step: step);
      
      await AuditService.log(userId, 'EXPENSE_APPROVED', {
        'type': type,
        'expenseId': id,
        'newStatus': newStatus,
        'step': step,
      });
      
      await NotificationService.createNotification(
        userId: expense.createdBy!,
        title: 'Depense Approuvée',
        message: 'Votre dépense ($type) de ${expense.montant} DT a été approuvée ($newStatus).',
        type: 'EXPENSE_APPROVED',
      );
      
      return {'success': true, 'message': 'Expense approved successfully to \$newStatus'};
    } catch (e) {
      return {'success': false, 'message': 'Approval failed: \$e'};
    }
  }

  Future<Map<String, dynamic>> rejectExpense(String type, int id, String userId) async {
    try {
      final expense = type == 'project' 
          ? await getProjectExpenseById(id) 
          : await getCompanyExpenseById(id);
          
      await _repository.updateExpenseStatus(type, id, 'rejected', userId);
      
      await AuditService.log(userId, 'EXPENSE_REJECTED', {
        'type': type,
        'expenseId': id,
      });
      
      if (expense != null && expense.createdBy != null) {
        await NotificationService.createNotification(
          userId: expense.createdBy!,
          title: 'Depense Rejetée',
          message: 'Votre dépense ($type) de ${expense.montant} DT a été rejetée.',
          type: 'EXPENSE_REJECTED',
        );
      }
      return {'success': true, 'message': 'Expense rejected'};
    } catch (e) {
      return {'success': false, 'message': 'Rejection failed: \$e'};
    }
  }
}
