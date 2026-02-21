import 'package:get_it/get_it.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';

final GetIt getIt = GetIt.instance;

void setupLocator() {
  getIt
    ..registerLazySingleton<SecureStorageService>(SecureStorageService.new)
    ..registerLazySingleton<WidgetDataService>(WidgetDataService.new)
    ..registerLazySingleton<ConfigViewModel>(ConfigViewModel.new)
    ..registerLazySingleton<HomeViewModel>(HomeViewModel.new);
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
