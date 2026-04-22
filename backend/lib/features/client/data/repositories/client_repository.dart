import '../../../../shared/database/connection.dart';
import '../models/client_model.dart';

class ClientRepository {
  final _db = DBConnection.getConnection();

  Future<List<ClientModel>> getAllClients({String? type, String? search, int limit = 50, int offset = 0}) async {
    String query = 'SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit, solde_du, matricule_fiscale, adresse, patente_document FROM clients WHERE 1=1';
    Map<String, dynamic> params = {};

    if (type != null && type.isNotEmpty) {
      query += ' AND type = :type';
      params['type'] = type == 'entreprise' ? 'Entreprise' : 'Particulier';
    }

    if (search != null && search.isNotEmpty) {
      query += ' AND (nom LIKE :search OR prenom LIKE :search OR raison_sociale LIKE :search OR email LIKE :search)';
      params['search'] = '%$search%';
    }

    query += ' ORDER BY id DESC LIMIT :limit OFFSET :offset';
    params['limit'] = limit;
    params['offset'] = offset;

    final result = await _db.execute(query, params);
    return result.rows.map<ClientModel>((row) => ClientModel.fromMap(row.assoc())).toList();
  }

  Future<ClientModel?> getClientById(int id) async {
    final result = await _db.execute('''
      SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit, solde_du, matricule_fiscale, adresse, patente_document
      FROM clients
      WHERE id = :id
    ''', {'id': id});

    if (result.rows.isEmpty) return null;
    return ClientModel.fromMap(result.rows.first.assoc());
  }

  Future<ClientModel?> getClientByUserId(String userId) async {
    final result = await _db.execute('''
      SELECT id, nom, prenom, raison_sociale, email, telephone, type, score_credit, solde_du, matricule_fiscale, adresse, patente_document
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
    final fields = <String>[];
    final params = <String, dynamic>{'id': id};

    if (data.containsKey('nom')) {
      fields.add('nom = :nom');
      params['nom'] = data['nom'];
    }
    if (data.containsKey('prenom')) {
      fields.add('prenom = :prenom');
      params['prenom'] = data['prenom'];
    }
    if (data.containsKey('raisonSociale') || data.containsKey('raison_sociale')) {
      fields.add('raison_sociale = :raison_sociale');
      params['raison_sociale'] = data['raisonSociale'] ?? data['raison_sociale'];
    }
    if (data.containsKey('email')) {
      fields.add('email = :email');
      params['email'] = data['email'];
    }
    if (data.containsKey('telephone')) {
      fields.add('telephone = :telephone');
      params['telephone'] = data['telephone'];
    }
    if (data.containsKey('type')) {
      fields.add('type = :type');
      params['type'] = data['type'] == 'entreprise' ? 'Entreprise' : 'Particulier';
    }
    if (data.containsKey('matriculeFiscale') || data.containsKey('matricule_fiscale')) {
      fields.add('matricule_fiscale = :matricule_fiscale');
      params['matricule_fiscale'] = data['matriculeFiscale'] ?? data['matricule_fiscale'];
    }
    if (data.containsKey('adresse')) {
      fields.add('adresse = :adresse');
      params['adresse'] = data['adresse'];
    }
    if (data.containsKey('patente_document')) {
      fields.add('patente_document = :patente_document');
      params['patente_document'] = data['patente_document'];
    }
    if (data.containsKey('score_credit')) {
      fields.add('score_credit = :score_credit');
      params['score_credit'] = data['score_credit'];
    }

    if (fields.isEmpty) return;

    final query = 'UPDATE clients SET ${fields.join(', ')} WHERE id = :id';
    await _db.execute(query, params);
  }

  Future<bool> deleteClient(int id) async {
    final result = await _db.execute('DELETE FROM clients WHERE id = :id', {'id': id});
    return (result.affectedRows.toInt()) > 0;
  }

  /// Dedicated method for finance debt update — avoids needing all client fields.
  Future<void> updateClientSolde(int id, double newSolde) async {
    await _db.execute(
      'UPDATE clients SET solde_du = :solde WHERE id = :id',
      {'solde': newSolde, 'id': id},
    );
  }
}
