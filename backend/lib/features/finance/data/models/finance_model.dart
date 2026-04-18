class InvoiceModel {
  final int? id;
  final int? projectId;
  final int? clientId;
  final String numeroFacture;
  final double montantHt;
  final double tva;
  final double montantTtc;
  final String? dateEmission;
  final String? dateEcheance;
  final String statut;
  final String? projectNom;

  InvoiceModel({
    this.id,
    this.projectId,
    this.clientId,
    required this.numeroFacture,
    this.montantHt = 0.0,
    this.tva = 0.0,
    this.montantTtc = 0.0,
    this.dateEmission,
    this.dateEcheance,
    required this.statut,
    this.projectNom,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'clientId': clientId,
      'numeroFacture': numeroFacture,
      'montantHt': montantHt,
      'tva': tva,
      'montantTtc': montantTtc,
      'dateEmission': dateEmission,
      'dateEcheance': dateEcheance,
      'statut': statut,
      'projectNom': projectNom,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      projectId: map['projet_id'] != null ? int.tryParse(map['projet_id'].toString()) : null,
      clientId: map['client_id'] != null ? int.tryParse(map['client_id'].toString()) : null,
      numeroFacture: map['numero_facture']?.toString() ?? '',
      montantHt: map['montant_ht'] != null ? double.tryParse(map['montant_ht'].toString()) ?? 0.0 : 0.0,
      tva: map['tva'] != null ? double.tryParse(map['tva'].toString()) ?? 0.0 : 0.0,
      montantTtc: map['montant_ttc'] != null ? double.tryParse(map['montant_ttc'].toString()) ?? 0.0 : 0.0,
      dateEmission: map['date_emission']?.toString(),
      dateEcheance: map['date_echeance']?.toString(),
      statut: map['statut']?.toString() ?? 'Brouillon',
      projectNom: map['project_nom']?.toString(),
    );
  }
}

class PaymentModel {
  final int? id;
  final int? invoiceId;
  final double montant;
  final String? mode;
  final String? datePaiement;
  final String? referenceTransaction;

  PaymentModel({
    this.id,
    this.invoiceId,
    required this.montant,
    this.mode,
    this.datePaiement,
    this.referenceTransaction,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'montant': montant,
      'mode': mode,
      'datePaiement': datePaiement,
      'referenceTransaction': referenceTransaction,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      invoiceId: map['facture_id'] != null ? int.tryParse(map['facture_id'].toString()) : null,
      montant: map['montant'] != null ? double.tryParse(map['montant'].toString()) ?? 0.0 : 0.0,
      mode: map['mode']?.toString(),
      datePaiement: map['date_paiement']?.toString(),
      referenceTransaction: map['reference_transaction']?.toString(),
    );
  }
}

class QuoteModel {
  final int? id;
  final int? projectId;
  final int clientId;
  final String numeroDevis;
  final double montantHt;
  final double tva;
  final double montantTtc;
  final String? dateEmission;
  final String? dateValidite;
  final String statut;
  final String? projectNom;
  final String? clientNom;

  QuoteModel({
    this.id,
    this.projectId,
    required this.clientId,
    required this.numeroDevis,
    this.montantHt = 0.0,
    this.tva = 0.0,
    this.montantTtc = 0.0,
    this.dateEmission,
    this.dateValidite,
    required this.statut,
    this.projectNom,
    this.clientNom,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'clientId': clientId,
      'numeroDevis': numeroDevis,
      'montantHt': montantHt,
      'tva': tva,
      'montantTtc': montantTtc,
      'dateEmission': dateEmission,
      'dateValidite': dateValidite,
      'statut': statut,
      'projectNom': projectNom,
      'clientNom': clientNom,
    };
  }

  factory QuoteModel.fromMap(Map<String, dynamic> map) {
    return QuoteModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      projectId: map['projet_id'] != null ? int.tryParse(map['projet_id'].toString()) : null,
      clientId: map['client_id'] != null ? int.tryParse(map['client_id'].toString()) ?? 0 : 0,
      numeroDevis: map['numero_devis']?.toString() ?? '',
      montantHt: map['montant_ht'] != null ? double.tryParse(map['montant_ht'].toString()) ?? 0.0 : 0.0,
      tva: map['tva'] != null ? double.tryParse(map['tva'].toString()) ?? 0.0 : 0.0,
      montantTtc: map['montant_ttc'] != null ? double.tryParse(map['montant_ttc'].toString()) ?? 0.0 : 0.0,
      dateEmission: map['date_emission']?.toString(),
      dateValidite: map['date_validite']?.toString(),
      statut: map['statut']?.toString() ?? 'Brouillon',
      projectNom: map['project_nom']?.toString(),
      clientNom: map['client_nom']?.toString(),
    );
  }
}
