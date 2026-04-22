class Invoice {
  final int? id;
  final int? projectId;
  final int? clientId;
  final String numeroFacture;
  final String type;
  final double montantHt;
  final double tva;
  final double timbre;
  final double montantTtc;
  final DateTime dateEmission;
  final DateTime dateEcheance;
  final String statut;
  final String? projectNom;

  Invoice({
    this.id,
    this.projectId,
    this.clientId,
    required this.numeroFacture,
    this.type = 'INVOICE',
    required this.montantHt,
    required this.tva,
    this.timbre = 1.0,
    required this.montantTtc,
    required this.dateEmission,
    required this.dateEcheance,
    this.statut = 'Brouillon',
    this.projectNom,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      projectId: json['projet_id'] is int ? json['projet_id'] : int.tryParse(json['projet_id']?.toString() ?? ''),
      clientId: json['client_id'] is int ? json['client_id'] : int.tryParse(json['client_id']?.toString() ?? ''),
      numeroFacture: json['numero_facture'] ?? '',
      type: json['type'] ?? 'INVOICE',
      montantHt: double.tryParse(json['montant_ht']?.toString() ?? '0') ?? 0.0,
      tva: double.tryParse(json['tva']?.toString() ?? '0') ?? 0.0,
      timbre: double.tryParse(json['timbre']?.toString() ?? '1.0') ?? 1.0,
      montantTtc: double.tryParse(json['montant_ttc']?.toString() ?? '0') ?? 0.0,
      dateEmission: DateTime.tryParse(json['date_emission']?.toString() ?? '') ?? DateTime.now(),
      dateEcheance: DateTime.tryParse(json['date_echeance']?.toString() ?? '') ?? DateTime.now(),
      statut: json['statut'] ?? 'Brouillon',
      projectNom: json['project_nom'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projet_id': projectId,
      'client_id': clientId,
      'numero_facture': numeroFacture,
      'type': type,
      'montant_ht': montantHt,
      'tva': tva,
      'timbre': timbre,
      'montant_ttc': montantTtc,
      'date_emission': dateEmission.toIso8601String().split('T')[0],
      'date_echeance': dateEcheance.toIso8601String().split('T')[0],
      'statut': statut,
    };
  }
}

class Payment {
  final int? id;
  final int factureId;
  final double montant;
  final String mode;
  final DateTime datePaiement;
  final String? referenceTransaction;

  Payment({
    this.id,
    required this.factureId,
    required this.montant,
    required this.mode,
    required this.datePaiement,
    this.referenceTransaction,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      factureId: json['facture_id'] is int ? json['facture_id'] : int.tryParse(json['facture_id']?.toString() ?? '0') ?? 0,
      montant: double.tryParse(json['montant']?.toString() ?? '0') ?? 0.0,
      mode: json['mode'] ?? 'Virement',
      datePaiement: DateTime.tryParse(json['date_paiement']?.toString() ?? '') ?? DateTime.now(),
      referenceTransaction: json['reference_transaction'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facture_id': factureId,
      'montant': montant,
      'mode': mode,
      'date_paiement': datePaiement.toIso8601String().split('T')[0],
      'reference_transaction': referenceTransaction,
    };
  }
}

class Quote {
  final int? id;
  final int? projectId;
  final int clientId;
  final String numeroDevis;
  final double montantHt;
  final double tva;
  final double montantTtc;
  final DateTime dateEmission;
  final DateTime dateValidite;
  final String statut;
  final String? projectNom;
  final String? clientNom;

  Quote({
    this.id,
    this.projectId,
    required this.clientId,
    required this.numeroDevis,
    required this.montantHt,
    required this.tva,
    required this.montantTtc,
    required this.dateEmission,
    required this.dateValidite,
    this.statut = 'Brouillon',
    this.projectNom,
    this.clientNom,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      projectId: json['projet_id'] is int ? json['projet_id'] : int.tryParse(json['projet_id']?.toString() ?? ''),
      clientId: json['client_id'] is int ? json['client_id'] : int.tryParse(json['client_id']?.toString() ?? '0') ?? 0,
      numeroDevis: json['numero_devis'] ?? '',
      montantHt: double.tryParse(json['montant_ht']?.toString() ?? '0') ?? 0.0,
      tva: double.tryParse(json['tva']?.toString() ?? '0') ?? 0.0,
      montantTtc: double.tryParse(json['montant_ttc']?.toString() ?? '0') ?? 0.0,
      dateEmission: DateTime.tryParse(json['date_emission']?.toString() ?? '') ?? DateTime.now(),
      dateValidite: DateTime.tryParse(json['date_validite']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      statut: json['statut'] ?? 'Brouillon',
      projectNom: json['project_nom'],
      clientNom: json['client_nom'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projet_id': projectId,
      'client_id': clientId,
      'numero_devis': numeroDevis,
      'montant_ht': montantHt,
      'tva': tva,
      'montant_ttc': montantTtc,
      'date_emission': dateEmission.toIso8601String().split('T')[0],
      'date_validite': dateValidite.toIso8601String().split('T')[0],
      'statut': statut,
    };
  }
}
