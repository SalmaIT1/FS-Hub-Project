import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
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
      
      // Check if user exists, if not create one
      String? userId = data['userId'];
      if (userId == null) {
        // Create user account first
        final userResult = await conn.execute('''
          INSERT INTO users (username, email, password, role, created_at)
          VALUES (:username, :email, :password, :role, NOW())
        ''', {
          'username': data['username'],
          'email': data['email'],
          'password': 'default_password', // Should be hashed in production
          'role': data['role'] ?? 'Employé',
        });

        // Get the created user ID
        final selectResult = await conn.execute('SELECT LAST_INSERT_ID() as id');
        userId = selectResult.rows.first.colByName('id').toString();
      }
      
      // Insert employee record
      await conn.execute('''
        INSERT INTO employees (user_id, matricule, nom, prenom, dateNaissance, sexe, 
                              photo, email, telephone, adresse, ville, poste, 
                              departement, dateEmbauche, typeContrat, statut)
        VALUES (:userId, :matricule, :nom, :prenom, :dateNaissance, :sexe, 
                :photo, :email, :telephone, :adresse, :ville, :poste, 
                :departement, :dateEmbauche, :typeContrat, :statut)
      ''', {
        'userId': userId,
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