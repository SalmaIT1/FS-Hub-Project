import 'package:fs_hub_backend/shared/database/migrations.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';

void main() async {
  print('--- FS-HUB MIGRATION RUNNER ---');
  try {
    // We need to init secret even for migration if it touches Auth
    AuthService.initSecret();
    
    await Migrations.initializeDatabase();
    
    print('--- MIGRATIONS COMPLETED SUCCESSFULLY ---');
  } catch (e, stack) {
    print('--- MIGRATIONS FAILED ---');
    print(e);
    print(stack);
  } finally {
    // Process exit will close connections
  }
}
