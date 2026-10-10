import 'package:get_it/get_it.dart';
import 'package:tapo/services/desktop_shell.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/tray_controller.dart';
import 'package:tapo/services/widget_data_service.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/viewmodels/launch_at_startup_viewmodel.dart';

final GetIt getIt = GetIt.instance;

void setupLocator() {
  getIt
    ..registerLazySingleton<SecureStorageService>(SecureStorageService.new)
    ..registerLazySingleton<WidgetDataService>(WidgetDataService.new)
    ..registerLazySingleton<ConfigViewModel>(ConfigViewModel.new)
    ..registerLazySingleton<HomeViewModel>(HomeViewModel.new)
    // Desktop only: the runner channel is never called on mobile.
    ..registerLazySingleton<DesktopShell>(DesktopShell.new)
    ..registerLazySingleton<LaunchAtStartupViewModel>(
      LaunchAtStartupViewModel.new,
    )
    ..registerLazySingleton<TrayController>(
      () => TrayController(
        shell: getIt<DesktopShell>(),
        home: getIt<HomeViewModel>(),
        launchAtStartup: getIt<LaunchAtStartupViewModel>(),
      ),
    );
}

/// Register TapoService with credentials (call after user authenticates)
Future<void> registerTapoService(String email, String password) async {
  if (getIt.isRegistered<TapoService>()) {
    await getIt.unregister<TapoService>();
  }
  getIt.registerLazySingleton<TapoService>(
    () => TapoService.fromCredentials(email, password),
  );
}
