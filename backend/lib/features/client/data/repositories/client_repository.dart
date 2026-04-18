import '../../../../shared/database/connection.dart';
import '../models/client_model.dart';

class ClientRepository {
  final _db = DBConnection.getConnection();

  Future<List<ClientModel>> getAllClients() async {
    final result = await _db.execute('''
      SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit, credit, matricule_fiscale, adresse, patente_document
      FROM clients
      ORDER BY id DESC
    ''');
    return result.rows.map<ClientModel>((row) => ClientModel.fromMap(row.assoc())).toList();
  }

  Future<ClientModel?> getClientById(int id) async {
    final result = await _db.execute('''
      SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit, credit, matricule_fiscale, adresse, patente_document
      FROM clients
      WHERE id = :id
    ''', {'id': id});

    if (result.rows.isEmpty) return null;
    return ClientModel.fromMap(result.rows.first.assoc());
  }

  Future<ClientModel?> getClientByUserId(String userId) async {
    final result = await _db.execute('''
      SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit, credit, matricule_fiscale, adresse, patente_document
      FROM clients
      WHERE user_id = :uid
    ''', {'uid': userId});

    if (result.rows.isEmpty) return null;
    return ClientModel.fromMap(result.rows.first.assoc());
  }

  Future<int> createClient(Map<String, dynamic> data) async {
    String clientType = data['type'] == 'entreprise' ? 'Entreprise' : 'Particulier';
    
    final result = await _db.transaction((txn) async {
      await txn.execute('''
        INSERT INTO clients (nom, prenom, raison_sociale, email, telephone, type, score_credit, user_id, matricule_fiscale, adresse, patente_document)
        VALUES (:nom, :prenom, :raison_sociale, :email, :telephone, :type, 0, :user_id, :matricule_fiscale, :adresse, :patente_document)
      ''', {
        'nom': data['nom'],
        'prenom': data['prenom'],
        'raison_sociale': data['raisonSociale'],
        'email': data['email'],
        'telephone': data['telephone'],
        'type': clientType,
        'user_id': data['user_id'],
        'matricule_fiscale': data['matriculeFiscale'],
        'adresse': data['adresse'],
        'patente_document': data['patenteDocument'],
      });

      final idRes = await txn.execute('SELECT LAST_INSERT_ID() as id');
      return int.tryParse(idRes.rows.first.colByName('id').toString()) ?? 0;
    });
    
    return result;
  }

  Future<void> updateClient(int id, Map<String, dynamic> data) async {
    String clientType = data['type'] == 'entreprise' ? 'Entreprise' : 'Particulier';

    await _db.execute('''
      UPDATE clients 
      SET nom = :nom, prenom = :prenom, raison_sociale = :raison_sociale, email = :email, telephone = :telephone, type = :type,
          matricule_fiscale = :matricule_fiscale, adresse = :adresse, patente_document = :patente_document
      WHERE id = :id
    ''', {
      'nom': data['nom'],
      'prenom': data['prenom'],
      'raison_sociale': data['raisonSociale'],
      'email': data['email'],
      'telephone': data['telephone'],
      'type': clientType,
      'matricule_fiscale': data['matriculeFiscale'],
      'adresse': data['adresse'],
      'patente_document': data['patenteDocument'],
      'id': id,
    });
  }

  Future<bool> deleteClient(int id) async {
    final result = await _db.execute('DELETE FROM clients WHERE id = :id', {'id': id});
    return (result.affectedRows.toInt()) > 0;
  }

  /// Dedicated method for finance credit deduction — avoids needing all client fields.
  Future<void> updateClientCredit(int id, double newCredit) async {
    await _db.execute(
      'UPDATE clients SET credit = :credit WHERE id = :id',
      {'credit': newCredit, 'id': id},
    );
  }
}
