import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    // Test employee creation with new user (no userId)
    final response = await http.post(
      Uri.parse('http://localhost:8080/v1/employees'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer dummy_token', // Just to bypass auth check for testing
      },
      body: jsonEncode({
        'matricule': 'TEST004',
        'nom': 'Test',
        'prenom': 'User',
        'dateNaissance': '1995-05-15',
        'sexe': 'Homme',
        'photo': '',
        'email': 'test4@example.com',
        'telephone': '1234567890',
        'adresse': '123 Test St',
        'ville': 'Test City',
        'poste': 'Developer',
        'departement': 'IT',
        'dateEmbauche': '2023-01-01',
        'typeContrat': 'CDI',
        'statut': 'Actif',
        'username': 'testuser4',
        'role': 'Employé'
      }),
    );

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
