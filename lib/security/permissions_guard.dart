/// Client-side UI hint helper for conditional rendering.
///
/// ⚠ THIS IS NOT A SECURITY BOUNDARY.
/// All actual permission enforcement happens on the backend (Dart Shelf server).
/// These helpers only help the Flutter UI decide whether to *render* certain
/// widgets (e.g., hide an "Upload" button for users without upload permission).
/// A determined user could bypass these checks, but the server will still reject
/// unauthorized API calls.
class PermissionsGuard {
  final String userId;

  /// The list of permission keys the server returned on login (e.g., 'manage_employees').
  final List<String> permissions;

  PermissionsGuard({required this.userId, required this.permissions});

  /// Returns true if the user has the given server-side permission key.
  bool has(String permission) => permissions.contains(permission);

  /// Returns true if the user has ANY of the given server-side permission keys.
  bool hasAny(List<String> perms) => perms.any(permissions.contains);

  /// Returns true if the user has ALL of the given server-side permission keys.
  bool hasAll(List<String> perms) => perms.every(permissions.contains);
}
