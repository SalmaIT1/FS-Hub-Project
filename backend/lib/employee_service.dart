import 'dart:convert';
import 'package:mysql_client/mysql_client.dart';
import 'db.dart';

class EmployeeService {
  static Future<Map<String, dynamic>> getAllEmployees() async {
    try {
      final conn = await DB.getConnection();
      
      final result = await conn.execute('''
        SELECT 
          e.*,
          u.username,
          u.role,
          u.permissions
        FROM employees e
        LEFT JOIN users u ON e.user_id = u.id
        ORDER BY e.created_at DESC
      ''');

      final employees = [];
      for (final row in result.rows) {
        employees.add({
          'id': row.colByName('id'),
          'matricule': row.colByName('matricule'),
          'nom': row.colByName('nom'),
          'prenom': row.colByName('prenom'),
          'dateNaissance': row.colByName('dateNaissance')?.toString(),
          'sexe': row.colByName('sexe'),
          'email': row.colByName('email'),
          'telephone': row.colByName('telephone'),
          'adresse': row.colByName('adresse'),
          'ville': row.colByName('ville'),
          'poste': row.colByName('poste'),
          'departement': row.colByName('departement'),
          'dateEmbauche': row.colByName('dateEmbauche')?.toString(),
          'typeContrat': row.colByName('typeContrat'),
          'statut': row.colByName('statut'),
          'username': row.colByName('username'),
          'role': row.colByName('role'),
          'permissions': row.colByName('permissions'),
          'avatarUrl': row.colByName('photo'),
        });
      }

      await conn.close();
      return {'success': true, 'data': employees};
    } catch (e) {
      print('Error fetching employees: $e');
      return {'success': false, 'message': 'Failed to fetch employees'};
    }
  }

  static Future<Map<String, dynamic>> getEmployeeById(String id) async {
    try {
      final conn = await DB.getConnection();
      
      final result = await conn.execute(
        '''
        SELECT 
          e.*,
          u.username,
          u.role,
          u.permissions
        FROM employees e
        LEFT JOIN users u ON e.user_id = u.id
        WHERE e.id = :id
        ''',
        {'id': id},
      );

      if (result.rows.isEmpty) {
        await conn.close();
        return {'success': false, 'message': 'Employee not found'};
      }

      final row = result.rows.first;
      final employee = {
        'id': row.colByName('id'),
        'matricule': row.colByName('matricule'),
        'nom': row.colByName('nom'),
        'prenom': row.colByName('prenom'),
        'dateNaissance': row.colByName('dateNaissance')?.toString(),
        'sexe': row.colByName('sexe'),
        'email': row.colByName('email'),
        'telephone': row.colByName('telephone'),
        'adresse': row.colByName('adresse'),
        'ville': row.colByName('ville'),
        'poste': row.colByName('poste'),
        'departement': row.colByName('departement'),
        'dateEmbauche': row.colByName('dateEmbauche')?.toString(),
        'typeContrat': row.colByName('typeContrat'),
        'statut': row.colByName('statut'),
        'username': row.colByName('username'),
        'role': row.colByName('role'),
        'permissions': row.colByName('permissions'),
        'avatarUrl': row.colByName('photo'),
      };

      await conn.close();
      return {'success': true, 'data': employee};
    } catch (e) {
      print('Error fetching employee: $e');
      return {'success': false, 'message': 'Failed to fetch employee'};
    }
  }

  static Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    try {
      print('=== CREATE EMPLOYEE DEBUG ===');
      print('Photo data length: ${data['photo']?.length ?? 0} characters');
      final previewLength = data['photo'] != null ? (data['photo'].length < 100 ? data['photo'].length : 100) : 0;
      print('Photo data preview: ${data['photo']?.substring(0, previewLength)}...');
      print('============================');
      
      final conn = await DB.getConnection();

      // Call stored procedure to create employee with user account
      // Default password: @ForeverSoftware2026
      final result = await conn.execute(
        '''
        CALL CreateEmployeeWithUser(
          :username,
          :password,
          :role,
          :permissions,
          :matricule,
          :nom,
          :prenom,
          :dateNaissance,
          :sexe,
          :photo,
          :email,
          :telephone,
          :adresse,
          :ville,
          :poste,
          :departement,
          :dateEmbauche,
          :typeContrat,
          :statut
        )
        ''',
        {
          'username': data['username'],
          'password': '@ForeverSoftware2026', // Generic password
          'role': data['role'] ?? 'Employé',
          'permissions': data['permissions'] != null 
              ? jsonEncode(data['permissions']) 
              : null,
          'matricule': data['matricule'],
          'nom': data['nom'],
          'prenom': data['prenom'],
          'dateNaissance': data['dateNaissance'],
          'sexe': data['sexe'],
          'photo': data['photo'], // Base64 encoded image
          'email': data['email'],
          'telephone': data['telephone'],
          'adresse': data['adresse'],
          'ville': data['ville'],
          'poste': data['poste'],
          'departement': data['departement'],
          'dateEmbauche': data['dateEmbauche'],
          'typeContrat': data['typeContrat'],
          'statut': data['statut'],
        },
      );

      await conn.close();
      return {
        'success': true,
        'message': 'Employee created successfully with default password: @ForeverSoftware2026',
      };
    } catch (e) {
      print('Error creating employee: $e');
      return {'success': false, 'message': 'Failed to create employee: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> updateEmployee(String id, Map<String, dynamic> data) async {
    try {
      final conn = await DB.getConnection();

      // Build dynamic update query
      final updates = <String>[];
      final params = <String, dynamic>{'id': id};

      if (data.containsKey('matricule')) {
        updates.add('matricule = :matricule');
        params['matricule'] = data['matricule'];
      }
      if (data.containsKey('nom')) {
        updates.add('nom = :nom');
        params['nom'] = data['nom'];
      }
      if (data.containsKey('prenom')) {
        updates.add('prenom = :prenom');
        params['prenom'] = data['prenom'];
      }
      if (data.containsKey('dateNaissance')) {
        updates.add('dateNaissance = :dateNaissance');
        params['dateNaissance'] = data['dateNaissance'];
      }
      if (data.containsKey('sexe')) {
        updates.add('sexe = :sexe');
        params['sexe'] = data['sexe'];
      }
      if (data.containsKey('email')) {
        updates.add('email = :email');
        params['email'] = data['email'];
      }
      if (data.containsKey('telephone')) {
        updates.add('telephone = :telephone');
        params['telephone'] = data['telephone'];
      }
      if (data.containsKey('adresse')) {
        updates.add('adresse = :adresse');
        params['adresse'] = data['adresse'];
      }
      if (data.containsKey('ville')) {
        updates.add('ville = :ville');
        params['ville'] = data['ville'];
      }
      if (data.containsKey('poste')) {
        updates.add('poste = :poste');
        params['poste'] = data['poste'];
      }
      if (data.containsKey('departement')) {
        updates.add('departement = :departement');
        params['departement'] = data['departement'];
      }
      if (data.containsKey('dateEmbauche')) {
        updates.add('dateEmbauche = :dateEmbauche');
        params['dateEmbauche'] = data['dateEmbauche'];
      }
      if (data.containsKey('typeContrat')) {
        updates.add('typeContrat = :typeContrat');
        params['typeContrat'] = data['typeContrat'];
      }
      if (data.containsKey('statut')) {
        updates.add('statut = :statut');
        params['statut'] = data['statut'];
      }

      if (updates.isEmpty) {
        await conn.close();
        return {'success': false, 'message': 'No fields to update'};
      }

      await conn.execute(
        'UPDATE employees SET ${updates.join(', ')} WHERE id = :id',
        params,
      );

      // Update user account if role or permissions changed
      if (data.containsKey('role') || data.containsKey('permissions')) {
        final userUpdates = <String>[];
        final userParams = <String, dynamic>{};

        if (data.containsKey('role')) {
          userUpdates.add('role = :role');
          userParams['role'] = data['role'];
        }
        if (data.containsKey('permissions')) {
          userUpdates.add('permissions = :permissions');
          userParams['permissions'] = data['permissions'] != null 
              ? jsonEncode(data['permissions']) 
              : null;
        }

        if (userUpdates.isNotEmpty) {
          await conn.execute(
            '''
            UPDATE users 
            SET ${userUpdates.join(', ')} 
            WHERE id = (SELECT user_id FROM employees WHERE id = :emp_id)
            ''',
            {...userParams, 'emp_id': id},
          );
        }
      }

      await conn.close();
      return {'success': true, 'message': 'Employee updated successfully'};
    } catch (e) {
      print('Error updating employee: $e');
      return {'success': false, 'message': 'Failed to update employee'};
    }
  }

  static Future<Map<String, dynamic>> deleteEmployee(String id) async {
    try {
      final conn = await DB.getConnection();

      // Get the employee record to find the associated user
      final employeeResult = await conn.execute(
        'SELECT user_id FROM employees WHERE id = :id',
        {'id': id},
      );

      if (employeeResult.rows.isNotEmpty) {
        final userId = employeeResult.rows.first.colByName('user_id');
        
        // Delete the employee (this will cascade delete due to FK constraint if set up that way)
        await conn.execute(
          'DELETE FROM employees WHERE id = :id',
          {'id': id},
        );

        // Also delete the corresponding user account
        await conn.execute(
          'DELETE FROM users WHERE id = :user_id',
          {'user_id': userId},
        );
      } else {
        await conn.close();
        return {'success': false, 'message': 'Employee not found'};
      }

      await conn.close();
      return {'success': true, 'message': 'Employee and associated user account deleted successfully'};
    } catch (e) {
      print('Error deleting employee: $e');
      return {'success': false, 'message': 'Failed to delete employee'};
    }
  }
}
