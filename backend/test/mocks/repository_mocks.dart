import 'package:mocktail/mocktail.dart';
import 'package:fs_hub_backend/features/auth/domain/repositories/auth_repository_port.dart';
import 'package:fs_hub_backend/features/finance/domain/repositories/finance_repository_port.dart';
import 'package:fs_hub_backend/features/hr/domain/repositories/hr_repository_port.dart';
import 'package:fs_hub_backend/features/project/domain/repositories/project_repository_port.dart';

class MockFinanceRepository extends Mock implements FinanceRepositoryPort {}

class MockProjectRepository extends Mock implements ProjectRepositoryPort {}

class MockHrRepository extends Mock implements HrRepositoryPort {}

class MockAuthRepository extends Mock implements AuthRepositoryPort {}

/// Registers mocktail fallback values for typed `any()` matchers.
void registerRepositoryFallbacks() {
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(DateTime.now());
}
