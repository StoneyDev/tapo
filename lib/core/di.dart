import 'package:get_it/get_it.dart';
import '../services/secure_storage_service.dart';
import '../services/tapo_service.dart';
import '../viewmodels/config_viewmodel.dart';

final GetIt getIt = GetIt.instance;

void setupLocator() {
  // Services
  getIt.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  // ViewModels - registered as factory (new instance each time)
  getIt.registerFactory<ConfigViewModel>(() => ConfigViewModel());
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
