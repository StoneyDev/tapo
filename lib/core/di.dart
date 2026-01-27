import 'package:get_it/get_it.dart';
import '../services/secure_storage_service.dart';

final GetIt getIt = GetIt.instance;

void setupLocator() {
  // Services
  getIt.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  // ViewModels will be registered here in future stories
}
