/// Canonical project statuses — must match MySQL ENUM on `projets.statut`.
class ProjectStatus {
  ProjectStatus._();

  static const aVenir = 'A venir';
  static const enCours = 'En cours';
  static const termine = 'Terminé';
  static const suspendu = 'Suspendu';

  static const List<String> all = [aVenir, enCours, termine, suspendu];

  static String normalize(String? raw) {
    if (raw == null || raw.isEmpty) return aVenir;
    final s = raw.trim();
    switch (s) {
      case 'Planifie':
      case 'Planifié':
      case 'planifie':
      case aVenir:
        return aVenir;
      case 'En cours':
      case 'Active':
        return enCours;
      case 'Termine':
      case 'Terminé':
      case 'termine':
        return termine;
      case 'En retard':
      case 'Annulé':
      case suspendu:
        return suspendu;
      default:
        return all.contains(s) ? s : aVenir;
    }
  }

  static const _legacyInputs = {
    'Planifie',
    'Planifié',
    'planifie',
    'Termine',
    'Terminé',
    'termine',
    'En retard',
    'Annulé',
    'Active',
    'En cours',
  };

  /// Validates and returns canonical status; throws on unknown values.
  static String validate(String? raw) {
    if (raw == null || raw.isEmpty) return aVenir;
    final s = raw.trim();
    if (all.contains(s)) return s;
    if (_legacyInputs.contains(s)) return normalize(s);
    throw Exception(
      'Statut projet invalide: "$raw". Valeurs autorisées: ${all.join(", ")}',
    );
  }
}
