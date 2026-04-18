class Client {
  final int? id;
  final String nom;
  final String prenom;
  final String? raisonSociale;
  final String? email;
  final String? telephone;
  final ClientType type;
  final int scoreCredit;
  final double credit;
  final String? matriculeFiscale;
  final String? adresse;
  final String? patenteDocument;

  const Client({
    this.id,
    required this.nom,
    required this.prenom,
    this.raisonSociale,
    this.email,
    this.telephone,
    required this.type,
    this.scoreCredit = 0,
    this.credit = 0.0,
    this.matriculeFiscale,
    this.adresse,
    this.patenteDocument,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] == null ? null : int.tryParse(json['id'].toString()),
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      raisonSociale: json['raisonSociale'] as String? ?? json['raison_sociale'] as String?,
      email: json['email'] as String?,
      telephone: json['telephone'] as String?,
      type: ClientType.values.firstWhere(
        (e) => e.name.toLowerCase() == json['type']?.toString().toLowerCase(),
        orElse: () => ClientType.particulier,
      ),
      scoreCredit: int.tryParse((json['scoreCredit'] ?? json['score_credit'])?.toString() ?? '0') ?? 0,
      credit: double.tryParse((json['credit'])?.toString() ?? '0.0') ?? 0.0,
      matriculeFiscale: json['matriculeFiscale'] as String? ?? json['matricule_fiscale'] as String?,
      adresse: json['adresse'] as String?,
      patenteDocument: json['patenteDocument'] as String? ?? json['patente_document'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'prenom': prenom,
      'raisonSociale': raisonSociale,
      'email': email,
      'telephone': telephone,
      'type': type.name,
      'scoreCredit': scoreCredit,
      'credit': credit,
      'matriculeFiscale': matriculeFiscale,
      'adresse': adresse,
      'patenteDocument': patenteDocument,
    };
  }

  Client copyWith({
    int? id,
    String? nom,
    String? prenom,
    String? raisonSociale,
    String? email,
    String? telephone,
    ClientType? type,
    int? scoreCredit,
    double? credit,
    String? matriculeFiscale,
    String? adresse,
    String? patenteDocument,
  }) {
    return Client(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      raisonSociale: raisonSociale ?? this.raisonSociale,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      type: type ?? this.type,
      scoreCredit: scoreCredit ?? this.scoreCredit,
      credit: credit ?? this.credit,
      matriculeFiscale: matriculeFiscale ?? this.matriculeFiscale,
      adresse: adresse ?? this.adresse,
      patenteDocument: patenteDocument ?? this.patenteDocument,
    );
  }

  String get displayName {
    if (type == ClientType.entreprise && raisonSociale != null && raisonSociale!.isNotEmpty) {
      return raisonSociale!;
    }
    return '$nom $prenom'.trim();
  }

  String get fullName => '$nom $prenom'.trim();
}

enum ClientType {
  entreprise,
  particulier;

  String get displayName {
    switch (this) {
      case ClientType.entreprise:
        return 'Entreprise';
      case ClientType.particulier:
        return 'Particulier';
    }
  }
}
