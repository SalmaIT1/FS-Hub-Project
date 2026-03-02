class Invoice {
  final int? id;
  final int? projectId;
  final int? clientId;
  final String numeroFacture;
  final double montantHt;
  final double tva;
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
    required this.montantHt,
    required this.tva,
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
      montantHt: double.tryParse(json['montant_ht']?.toString() ?? '0') ?? 0.0,
      tva: double.tryParse(json['tva']?.toString() ?? '0') ?? 0.0,
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
      'montant_ht': montantHt,
      'tva': tva,
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
