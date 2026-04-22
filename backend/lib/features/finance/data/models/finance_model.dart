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
  final int? devisId;

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
    this.devisId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projet_id': projectId,
      'client_id': clientId,
      'numero_facture': numeroFacture,
      'montant_ht': montantHt,
      'tva': tva,
      'montant_ttc': montantTtc,
      'date_emission': dateEmission,
      'date_echeance': dateEcheance,
      'statut': statut,
      'project_nom': projectNom,
      'devis_id': devisId,
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
      devisId: map['devis_id'] != null ? int.tryParse(map['devis_id'].toString()) : null,
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
      'facture_id': invoiceId,
      'montant': montant,
      'mode': mode,
      'date_paiement': datePaiement,
      'reference_transaction': referenceTransaction,
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
      'projet_id': projectId,
      'client_id': clientId,
      'numero_devis': numeroDevis,
      'montant_ht': montantHt,
      'tva': tva,
      'montant_ttc': montantTtc,
      'date_emission': dateEmission,
      'date_validite': dateValidite,
      'statut': statut,
      'project_nom': projectNom,
      'client_nom': clientNom,
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
