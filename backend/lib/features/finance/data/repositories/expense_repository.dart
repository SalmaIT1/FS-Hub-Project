import 'package:mysql_client/mysql_client.dart';
import '../models/expense_model.dart';
import '../../../../shared/database/connection.dart';

class ExpenseRepository {
  final _db = DBConnection.getConnection();

  Future<List<ExpenseModel>> getAllProjectExpenses({int? projectId}) async {
    try {
      String query = '''
        SELECT e.*, ec.nom as category_name
        FROM depenses_projets e
        JOIN projets p ON e.projet_id = p.id
        LEFT JOIN expense_categories ec ON e.category_id = ec.id
        WHERE p.is_deleted = FALSE
      ''';
      
      Map<String, dynamic> params = {};
      if (projectId != null) {
        query += ' AND e.projet_id = :projectId';
        params['projectId'] = projectId;
      }
      
      query += ' ORDER BY e.date_depense DESC';
      
      final results = await _db.execute(query, params);
      return results.rows.map((row) => ExpenseModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<ExpenseModel?> getProjectExpenseById(int id) async {
    try {
      final results = await _db.execute('''
        SELECT e.*, ec.nom as category_name
        FROM depenses_projets e
        LEFT JOIN expense_categories ec ON e.category_id = ec.id
        WHERE e.id = :id
      ''', {'id': id});
      
      if (results.rows.isEmpty) return null;
      return ExpenseModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }

  Future<ExpenseModel> createProjectExpense(ExpenseModel expense) async {
    try {
      final results = await _db.execute('''
        INSERT INTO depenses_projets (montant, date_depense, description, projet_id, category_id, created_by, status)
        VALUES (:montant, :date_depense, :description, :projet_id, :category_id, :created_by, :status)
      ''', {
        'montant': expense.montant,
        'date_depense': expense.dateDepense.toIso8601String().split('T')[0],
        'description': expense.description,
        'projet_id': expense.projectId,
        'category_id': expense.categoryId,
        'created_by': expense.createdBy,
        'status': expense.status,
      });
      
      final id = results.lastInsertID.toInt();
      return expense.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create project expense: $e');
    }
  }

  Future<ExpenseModel> updateProjectExpense(ExpenseModel expense) async {
    try {
      await _db.execute('''
        UPDATE depenses_projets 
        SET montant = :montant, date_depense = :date_depense, description = :description, projet_id = :projet_id, category_id = :category_id, updated_at = CURRENT_TIMESTAMP
        WHERE id = :id
      ''', {
        'montant': expense.montant,
        'date_depense': expense.dateDepense.toIso8601String().split('T')[0],
        'description': expense.description,
        'projet_id': expense.projectId,
        'category_id': expense.categoryId,
        'id': expense.id,
      });
      
      return expense;
    } catch (e) {
      throw Exception('Failed to update project expense: $e');
    }
  }

  Future<bool> deleteProjectExpense(int id) async {
    try {
      final results = await _db.execute('DELETE FROM depenses_projets WHERE id = :id', {'id': id});
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<ExpenseModel>> getAllCompanyExpenses() async {
    try {
      final results = await _db.execute('''
        SELECT e.*, ec.nom as category_name
        FROM depenses_entreprise e
        LEFT JOIN expense_categories ec ON e.category_id = ec.id
        ORDER BY e.date_depense DESC
      ''');
      
      return results.rows.map((row) => ExpenseModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<ExpenseModel?> getCompanyExpenseById(int id) async {
    try {
      final results = await _db.execute('''
        SELECT e.*, ec.nom as category_name
        FROM depenses_entreprise e
        LEFT JOIN expense_categories ec ON e.category_id = ec.id
        WHERE e.id = :id
      ''', {'id': id});
      
      if (results.rows.isEmpty) return null;
      return ExpenseModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }

  Future<ExpenseModel> createCompanyExpense(ExpenseModel expense) async {
    try {
      final results = await _db.execute('''
        INSERT INTO depenses_entreprise (montant, date_depense, description, category_id, created_by, status)
        VALUES (:montant, :date_depense, :description, :category_id, :created_by, :status)
      ''', {
        'montant': expense.montant,
        'date_depense': expense.dateDepense.toIso8601String().split('T')[0],
        'description': expense.description,
        'category_id': expense.categoryId,
        'created_by': expense.createdBy,
        'status': expense.status,
      });
      
      final id = results.lastInsertID.toInt();
      return expense.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create company expense: $e');
    }
  }

  Future<ExpenseModel> updateCompanyExpense(ExpenseModel expense) async {
    try {
      await _db.execute('''
        UPDATE depenses_entreprise 
        SET montant = :montant, date_depense = :date_depense, description = :description, category_id = :category_id, updated_at = CURRENT_TIMESTAMP
        WHERE id = :id
      ''', {
        'montant': expense.montant,
        'date_depense': expense.dateDepense.toIso8601String().split('T')[0],
        'description': expense.description,
        'category_id': expense.categoryId,
        'id': expense.id,
      });
      
      return expense;
    } catch (e) {
      throw Exception('Failed to update company expense: $e');
    }
  }

  Future<bool> deleteCompanyExpense(int id) async {
    try {
      final results = await _db.execute('DELETE FROM depenses_entreprise WHERE id = :id', {'id': id});
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateExpenseStatus(String type, int id, String status, String userId, {String? step}) async {
    final table = type == 'project' ? 'depenses_projets' : 'depenses_entreprise';
    String column = '';
    if (step == 'manager') column = ', manager_id = :userId';
    if (step == 'hr') column = ', hr_id = :userId';
    if (step == 'finance') column = ', finance_id = :userId';

    await _db.execute('''
      UPDATE $table 
      SET status = :status $column, updated_at = CURRENT_TIMESTAMP
      WHERE id = :id
    ''', {
      'status': status,
      'userId': userId,
      'id': id,
    });
  }

  Future<List<ExpenseCategoryModel>> getAllExpenseCategories() async {
    try {
      final results = await _db.execute('SELECT * FROM expense_categories ORDER BY nom');
      return results.rows.map((row) => ExpenseCategoryModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<ExpenseCategoryModel?> getExpenseCategoryById(int id) async {
    try {
      final results = await _db.execute('SELECT * FROM expense_categories WHERE id = :id', {'id': id});
      
      if (results.rows.isEmpty) return null;
      return ExpenseCategoryModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }

  Future<ExpenseCategoryModel> createExpenseCategory(ExpenseCategoryModel category) async {
    try {
      final results = await _db.execute('''
        INSERT INTO expense_categories (nom, description)
        VALUES (:nom, :description)
      ''', {
        'nom': category.nom,
        'description': category.description,
      });
      
      final id = results.lastInsertID.toInt();
      return category.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create expense category: $e');
    }
  }

  Future<ExpenseCategoryModel> updateExpenseCategory(ExpenseCategoryModel category) async {
    try {
      await _db.execute('''
        UPDATE expense_categories 
        SET nom = :nom, description = :description
        WHERE id = :id
      ''', {
        'nom': category.nom,
        'description': category.description,
        'id': category.id,
      });
      
      return category;
    } catch (e) {
      throw Exception('Failed to update expense category: $e');
    }
  }

  Future<bool> deleteExpenseCategory(int id) async {
    try {
      final results = await _db.execute('DELETE FROM expense_categories WHERE id = :id', {'id': id});
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getProjectExpenseSummary({int? projectId}) async {
    try {
      String query = '''
        SELECT 
          COUNT(*) as total_expenses,
          SUM(montant) as total_amount,
          COUNT(DISTINCT category_id) as category_count
        FROM depenses_projets
      ''';
      
      Map<String, dynamic> params = {};
      if (projectId != null) {
        query += ' WHERE projet_id = :projectId';
        params['projectId'] = projectId;
      }
      
      final results = await _db.execute(query, params);
      
      if (results.rows.isEmpty) return {};
      
      final row = results.rows.first;
      
      return {
        'total_expenses': row['total_expenses'],
        'total_amount': row['total_amount'],
        'category_count': row['category_count'],
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getCompanyExpenseSummary() async {
    try {
      final results = await _db.execute('''
        SELECT 
          COUNT(*) as total_expenses,
          SUM(montant) as total_amount,
          COUNT(DISTINCT category_id) as category_count
        FROM depenses_entreprise
      ''');
      
      if (results.rows.isEmpty) return {};
      
      final row = results.rows.first;
      
      return {
        'total_expenses': row['total_expenses'],
        'total_amount': row['total_amount'],
        'category_count': row['category_count'],
      };
    } catch (e) {
      return {};
    }
  }
}





