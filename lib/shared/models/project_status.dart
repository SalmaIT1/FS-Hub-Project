/// Canonical project statuses — must match MySQL ENUM on `projets.statut`.
class ProjectStatus {
  ProjectStatus._();

  static const aVenir = 'A venir';
  static const enCours = 'En cours';
  static const termine = 'Terminé';
  static const suspendu = 'Suspendu';

  static const List<String> all = [aVenir, enCours, termine, suspendu];

  static const Map<String, String> labelsFr = {
    aVenir: 'À venir',
    enCours: 'En cours',
    termine: 'Terminé',
    suspendu: 'Suspendu',
  };

  /// Maps legacy UI/API values to DB enum.
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
      case suspendu:
        return suspendu;
      default:
        return all.contains(s) ? s : aVenir;
    }
  }
}
