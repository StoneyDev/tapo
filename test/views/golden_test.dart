import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/main.dart' show appTheme, darkAppTheme;
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/viewmodels/launch_at_startup_viewmodel.dart';
import 'package:tapo/views/config_screen.dart';
import 'package:tapo/views/home_screen.dart';

import '../helpers/fake_desktop_shell.dart';

// --- Mock ViewModels ---

class MockHomeViewModel extends ChangeNotifier implements HomeViewModel {
  List<TapoDevice> _devices = [];
  final bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _togglingDevices = {};

  @override
  List<TapoDevice> get devices => List.unmodifiable(_devices);
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool isToggling(String ip) => _togglingDevices.contains(ip);
  @override
  Duration? powerOffRemaining(String ip) => null;
  @override
  void schedulePowerOff(String ip) {}
  @override
  void cancelPowerOff(String ip, {bool notify = true}) {}
  @override
  void cancelAllPowerOffs() {}

  void setDevices(List<TapoDevice> devices) {
    _devices = devices;
    notifyListeners();
  }

  void setIsLoading({required bool loading}) {
    // _isLoading is final; not used in golden tests
    notifyListeners();
  }

  @override
  Future<void> loadDevices({bool silent = false}) async {}
  @override
  Future<void> refresh({bool silent = false}) async {}
  @override
  Future<void> refreshIfStale(Duration maxAge) async {}
  @override
  Future<void> turnOffAll() async {}
  @override
  Future<bool> toggleDevice(String ip) async => true;
  @override
  Future<void> removeDevice(String ip) async {}
  @override
  Future<void> updateDeviceIp(String oldIp, String newIp) async {}
}

class MockConfigViewModel extends ChangeNotifier implements ConfigViewModel {
  List<String> _deviceIps = [];
  final bool _isLoading = false;
  String? _errorMessage;

  @override
  List<String> get deviceIps => List.unmodifiable(_deviceIps);
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;

  void setDeviceIps(List<String> ips) {
    _deviceIps = ips;
    notifyListeners();
  }

  @override
  void addDeviceIp(String ip) {}
  @override
  void removeDeviceIp(String ip) {}
  @override
  Future<({String email, String password})> loadConfig() async =>
      (email: 'user@example.com', password: '');
  @override
  Future<bool> saveConfig(String email, String password) async => true;
}

class MockSecureStorageService implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTapoService implements TapoService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _devices = [
  TapoDevice(
    ip: '192.168.1.10',
    nickname: 'Lampe Salon',
    model: 'P110',
    deviceOn: true,
    isOnline: true,
  ),
  TapoDevice(
    ip: '192.168.1.11',
    nickname: 'Bureau',
    model: 'P100',
    deviceOn: false,
    isOnline: true,
  ),
  TapoDevice(
    ip: '192.168.1.12',
    nickname: 'Chambre',
    model: 'P110',
    deviceOn: false,
    isOnline: false,
  ),
];

/// Windows renders with the compact density of desktop platforms.
ThemeData _desktop(ThemeData theme) => theme.copyWith(
  platform: TargetPlatform.windows,
  visualDensity: VisualDensity.compact,
);

const _desktopSize = Size(1000, 660);

void main() {
  final getIt = GetIt.instance;

  // Build the themes before any platform override so they keep the test
  // fonts (Segoe UI, the Windows default, is not available in tests).
  setUpAll(() => [appTheme, darkAppTheme]);

  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('golden', () {
    testWidgets('home screen with devices', (tester) async {
      final vm = MockHomeViewModel();
      getIt
        ..registerSingleton<HomeViewModel>(vm)
        ..registerSingleton<SecureStorageService>(MockSecureStorageService())
        ..registerSingleton<TapoService>(MockTapoService());

      vm.setDevices(_devices);

      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_screen.png'),
      );
    });

    testWidgets('config screen with IPs', (tester) async {
      final vm = MockConfigViewModel();
      getIt.registerSingleton<ConfigViewModel>(vm);

      vm.setDeviceIps(['192.168.1.10', '192.168.1.11']);

      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          home: const ConfigScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/config_screen.png'),
      );
    });

    for (final (name, theme) in [('light', appTheme), ('dark', darkAppTheme)]) {
      testWidgets('desktop home screen ($name)', (tester) async {
        final vm = MockHomeViewModel();
        getIt
          ..registerSingleton<HomeViewModel>(vm)
          ..registerSingleton<SecureStorageService>(MockSecureStorageService())
          ..registerSingleton<TapoService>(MockTapoService())
          ..registerSingleton<LaunchAtStartupViewModel>(
            LaunchAtStartupViewModel(
              shell: FakeDesktopShell()..launchAtStartup = true,
            ),
          );
        vm.setDevices(_devices);
        await getIt<LaunchAtStartupViewModel>().load();

        await tester.binding.setSurfaceSize(_desktopSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _desktop(theme),
            home: const HomeScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/desktop_home_$name.png'),
        );
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }

    testWidgets('desktop config screen', (tester) async {
      final vm = MockConfigViewModel();
      getIt.registerSingleton<ConfigViewModel>(vm);
      vm.setDeviceIps(['192.168.1.10', '192.168.1.11']);

      await tester.binding.setSurfaceSize(_desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _desktop(appTheme),
          home: const ConfigScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop_config_screen.png'),
      );
    });
  });
}
