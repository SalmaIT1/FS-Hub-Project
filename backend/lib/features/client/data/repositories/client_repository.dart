import '../../../../shared/database/connection.dart';
import '../models/client_model.dart';

class ClientRepository {
  final _db = DBConnection.getConnection();

  Future<List<ClientModel>> getAllClients() async {
    final result = await _db.execute('''
      SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit
      FROM clients
      ORDER BY id DESC
    ''');
    return result.rows.map<ClientModel>((row) => ClientModel.fromMap(row.assoc())).toList();
  }

  Future<ClientModel?> getClientById(int id) async {
    final result = await _db.execute('''
      SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit
      FROM clients
      WHERE id = :id
    ''', {'id': id});

    if (result.rows.isEmpty) return null;
    return ClientModel.fromMap(result.rows.first.assoc());
  }

  Future<int> createClient(Map<String, dynamic> data) async {
    String clientType = data['type'] == 'entreprise' ? 'Entreprise' : 'Particulier';
    
    final result = await _db.transaction((txn) async {
      await txn.execute('''
        INSERT INTO clients (nom, prenom, raison_sociale, email, telephone, type, score_credit)
        VALUES (:nom, :prenom, :raison_sociale, :email, :telephone, :type, 0)
      ''', {
        'nom': data['nom'],
        'prenom': data['prenom'],
        'raison_sociale': data['raisonSociale'],
        'email': data['email'],
        'telephone': data['telephone'],
        'type': clientType,
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
      SET nom = :nom, prenom = :prenom, raison_sociale = :raison_sociale, email = :email, telephone = :telephone, type = :type
      WHERE id = :id
    ''', {
      'nom': data['nom'],
      'prenom': data['prenom'],
      'raison_sociale': data['raisonSociale'],
      'email': data['email'],
      'telephone': data['telephone'],
      'type': clientType,
      'id': id,
    });
  }

  Future<bool> deleteClient(int id) async {
    final result = await _db.execute('DELETE FROM clients WHERE id = :id', {'id': id});
    return result.affectedRows > 0;
  }
}
