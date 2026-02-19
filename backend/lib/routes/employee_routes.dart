import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../database/db_connection.dart';

class EmployeeRoutes {
  late final Router router;

  EmployeeRoutes() {
    router = Router()
      ..get('/', _getAllEmployees)
      ..get('/<id>', _getEmployeeById)
      ..post('/', _createEmployee)
      ..put('/<id>', _updateEmployee)
      ..delete('/<id>', _deleteEmployee);
  }

  Future<Response> _getAllEmployees(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      
      // Fetch all employees with related user info
      final result = await conn.execute('''
        SELECT e.id, e.user_id, e.matricule, e.nom, e.prenom, e.dateNaissance, 
               e.sexe, e.photo, e.email, e.telephone, e.adresse, e.ville, 
               e.poste, e.departement, e.dateEmbauche, e.typeContrat, e.statut,
               e.created_at, e.updated_at,
               u.username, u.role
        FROM employees e
        LEFT JOIN users u ON e.user_id = u.id
        ORDER BY e.created_at DESC
      ''');

      final employees = result.rows.map((row) {
        return {
          'id': row.colByName('id'),
          'userId': row.colByName('user_id'),
          'matricule': row.colByName('matricule'),
          'nom': row.colByName('nom'),
          'prenom': row.colByName('prenom'),
          'dateNaissance': row.colByName('dateNaissance'),
          'sexe': row.colByName('sexe'),
          'photo': row.colByName('photo'),
          'email': row.colByName('email'),
          'telephone': row.colByName('telephone'),
          'adresse': row.colByName('adresse'),
          'ville': row.colByName('ville'),
          'poste': row.colByName('poste'),
          'departement': row.colByName('departement'),
          'dateEmbauche': row.colByName('dateEmbauche'),
          'typeContrat': row.colByName('typeContrat'),
          'statut': row.colByName('statut'),
          'createdAt': row.colByName('created_at'),
          'updatedAt': row.colByName('updated_at'),
          'username': row.colByName('username'),
          'role': row.colByName('role'),
        };
      }).toList();

      return Response.ok(
        jsonEncode({'success': true, 'data': employees}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error fetching employees: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getEmployeeById(Request request, String id) async {
    try {
      final conn = DBConnection.getConnection();
      
      // Fetch specific employee with related user info
      final result = await conn.execute('''
        SELECT e.id, e.user_id, e.matricule, e.nom, e.prenom, e.dateNaissance, 
               e.sexe, e.photo, e.email, e.telephone, e.adresse, e.ville, 
               e.poste, e.departement, e.dateEmbauche, e.typeContrat, e.statut,
               e.created_at, e.updated_at,
               u.username, u.role
        FROM employees e
        LEFT JOIN users u ON e.user_id = u.id
        WHERE e.id = :id
      ''', {'id': id});

      if (result.rows.isEmpty) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Employee not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = result.rows.first;
      final employee = {
        'id': row.colByName('id'),
        'userId': row.colByName('user_id'),
        'matricule': row.colByName('matricule'),
        'nom': row.colByName('nom'),
        'prenom': row.colByName('prenom'),
        'dateNaissance': row.colByName('dateNaissance'),
        'sexe': row.colByName('sexe'),
        'photo': row.colByName('photo'),
        'email': row.colByName('email'),
        'telephone': row.colByName('telephone'),
        'adresse': row.colByName('adresse'),
        'ville': row.colByName('ville'),
        'poste': row.colByName('poste'),
        'departement': row.colByName('departement'),
        'dateEmbauche': row.colByName('dateEmbauche'),
        'typeContrat': row.colByName('typeContrat'),
        'statut': row.colByName('statut'),
        'createdAt': row.colByName('created_at'),
        'updatedAt': row.colByName('updated_at'),
        'username': row.colByName('username'),
        'role': row.colByName('role'),
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': employee}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error fetching employee: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _createEmployee(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final conn = DBConnection.getConnection();
      
      // Debug: Print database info
      print('Creating employee with data: $data');
      
      // Generate a new random ID for both user and employee
      final randomId = const Uuid().v4();
      String? userId = data['userId'];

      if (userId == null) {
        // Check if username already exists first
        final existingUser = await conn.execute('''
          SELECT id FROM users WHERE username = :username
        ''', {'username': data['username']});
        
        if (existingUser.rows.isNotEmpty) {
          return Response.internalServerError(
            body: jsonEncode({
              'success': false, 
              'message': 'Username "${data['username']}" already exists'
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
        
        // Create user account with randomized ID
        userId = randomId;
        print('Creating user with ID: $userId, username: ${data['username']}');
        try {
          await conn.execute('''
            INSERT INTO users (id, username, password, role, created_at)
            VALUES (:id, :username, :password, :role, NOW())
          ''', {
            'id': userId,
            'username': data['username'],
            'password': data['password'] ?? 'default_password', // Use provided password
            'role': data['role'] ?? 'Employé',
          });
        } catch (insertError) {
          print('User INSERT failed: $insertError');
          throw Exception('Failed to create user: $insertError');
        }
      } else {
        // Verify user ID exists and is not already linked to an employee
        final existingEmployee = await conn.execute('''
          SELECT id FROM employees WHERE user_id = :userId
        ''', {'userId': userId});
        
        if (existingEmployee.rows.isNotEmpty) {
          return Response.internalServerError(
            body: jsonEncode({
              'success': false, 
              'message': 'User ID $userId is already linked to an employee'
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
      
      // Debug: Check table structure before INSERT
      final tableCheck = await conn.execute('DESCRIBE employees');
      print('Table columns: ${tableCheck.rows.map((r) => r.colByName("Field")).toList()}');
      
      // Insert employee record with the SAME ID as the user
      await conn.execute('''
        INSERT INTO employees (id, user_id, matricule, nom, prenom, dateNaissance, sexe, 
                              photo, email, telephone, adresse, ville, poste, 
                              departement, dateEmbauche, typeContrat, statut)
        VALUES (:id, :user_id, :matricule, :nom, :prenom, :dateNaissance, :sexe, 
                :photo, :email, :telephone, :adresse, :ville, :poste, 
                :departement, :dateEmbauche, :typeContrat, :statut)
      ''', {
        'id': userId, // Primary key is same as user_id for consistency
        'user_id': userId,
        'matricule': data['matricule'],
        'nom': data['nom'],
        'prenom': data['prenom'],
        'dateNaissance': data['dateNaissance'],
        'sexe': data['sexe'],
        'photo': data['photo'], // photo is LONGTEXT now
        'email': data['email'],
        'telephone': data['telephone'],
        'adresse': data['adresse'],
        'ville': data['ville'],
        'poste': data['poste'],
        'departement': data['departement'],
        'dateEmbauche': data['dateEmbauche'],
        'typeContrat': data['typeContrat'],
        'statut': data['statut']
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Employee created successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error creating employee: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _updateEmployee(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final conn = DBConnection.getConnection();
      
      // Update employee record
      await conn.execute('''
        UPDATE employees 
        SET matricule = :matricule, nom = :nom, prenom = :prenom, dateNaissance = :dateNaissance, sexe = :sexe, 
            photo = :photo, email = :email, telephone = :telephone, adresse = :adresse, ville = :ville, 
            poste = :poste, departement = :departement, dateEmbauche = :dateEmbauche, typeContrat = :typeContrat, 
            statut = :statut, updated_at = NOW()
        WHERE id = :id
      ''', {
        'matricule': data['matricule'],
        'nom': data['nom'],
        'prenom': data['prenom'],
        'dateNaissance': data['dateNaissance'],
        'sexe': data['sexe'],
        'photo': data['photo'],
        'email': data['email'],
        'telephone': data['telephone'],
        'adresse': data['adresse'],
        'ville': data['ville'],
        'poste': data['poste'],
        'departement': data['departement'],
        'dateEmbauche': data['dateEmbauche'],
        'typeContrat': data['typeContrat'],
        'statut': data['statut'],
        'id': id
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Employee updated successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error updating employee: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _deleteEmployee(Request request, String id) async {
    try {
      final conn = DBConnection.getConnection();
      
      // Delete employee record
      await conn.execute('DELETE FROM employees WHERE id = :id', {'id': id});

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Employee deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error deleting employee: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}