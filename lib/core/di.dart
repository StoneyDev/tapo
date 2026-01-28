import 'package:get_it/get_it.dart';
import '../services/secure_storage_service.dart';
import '../services/tapo_service.dart';

final GetIt getIt = GetIt.instance;

void setupLocator() {
  // Services
  getIt.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  // TapoService registered as factory - needs credentials, will be re-registered after login
  // Initially registered with empty credentials, re-register after auth
}

/// Register TapoService with credentials (call after user authenticates)
void registerTapoService(String email, String password) {
  if (getIt.isRegistered<TapoService>()) {
    getIt.unregister<TapoService>();
  }
  getIt.registerLazySingleton<TapoService>(
    () => TapoService.fromCredentials(email, password),
  );
}
