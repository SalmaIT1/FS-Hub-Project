class ClientModel {
  final int id;
  final String? nom;
  final String? prenom;
  final String? raisonSociale;
  final String? email;
  final String? telephone;
  final String type; // 'entreprise' or 'particulier'
  final double scoreCredit;

  ClientModel({
    required this.id,
    this.nom,
    this.prenom,
    this.raisonSociale,
    this.email,
    this.telephone,
    required this.type,
    this.scoreCredit = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'raisonSociale': raisonSociale,
      'email': email,
      'telephone': telephone,
      'type': type,
      'scoreCredit': scoreCredit,
    };
  }

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    String dbType = map['type']?.toString() ?? 'Particulier';
    String frontendType = dbType == 'Entreprise' ? 'entreprise' : 'particulier';
    
    return ClientModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) ?? 0 : 0,
      nom: map['nom']?.toString(),
      prenom: map['prenom']?.toString(),
      raisonSociale: map['raison_sociale']?.toString(),
      email: map['email']?.toString(),
      telephone: map['telephone']?.toString(),
      type: frontendType,
      scoreCredit: map['score_credit'] != null ? double.tryParse(map['score_credit'].toString()) ?? 0.0 : 0.0,
    );
  }
}
