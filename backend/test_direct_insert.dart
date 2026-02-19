import 'lib/database/db_connection.dart';

void main() async {
  await DBConnection.initialize();
  final conn = DBConnection.getConnection();
  
  try {
    // Test the exact same INSERT that's failing
    print('Testing INSERT with email column...');
    await conn.execute('''
      INSERT INTO employees (user_id, matricule, nom, prenom, dateNaissance, sexe, 
                              photo, email, telephone, adresse, ville, poste, 
                              departement, dateEmbauche, typeContrat, statut)
        VALUES (:userId, :matricule, :nom, :prenom, :dateNaissance, :sexe, 
                :photo, :email, :telephone, :adresse, :ville, :poste, 
                :departement, :dateEmbauche, :typeContrat, :statut)
    ''', {
      'userId': null, // This should trigger user creation
      'matricule': 'TEST005',
      'nom': 'Test',
      'prenom': 'User',
      'dateNaissance': '1995-05-15',
      'sexe': 'Homme',
      'photo': '',
      'email': 'test5@example.com',
      'telephone': '1234567890',
      'adresse': '123 Test St',
      'ville': 'Test City',
      'poste': 'Developer',
      'departement': 'IT',
      'dateEmbauche': '2023-01-01',
      'typeContrat': 'CDI',
      'statut': 'Actif'
    });
    
    print('INSERT successful');
  } catch (e) {
    print('INSERT Error: $e');
  }
}
