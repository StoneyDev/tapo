import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/views/config_screen.dart';
import 'package:tapo/views/home_screen.dart';

// --- Mock ViewModels (same pattern as existing widget tests) ---

class MockHomeViewModel extends ChangeNotifier implements HomeViewModel {
  List<TapoDevice> _devices = [];
  bool _isLoading = false;
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

  void setDevices(List<TapoDevice> devices) {
    _devices = devices;
    notifyListeners();
  }

  void setIsLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  Future<void> loadDevices() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> toggleDevice(String ip) async {}
  @override
  Future<void> removeDevice(String ip) async {}
}

class MockConfigViewModel extends ChangeNotifier implements ConfigViewModel {
  List<String> _deviceIps = [];
  bool _isLoading = false;
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

void main() {
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('golden', () {
    testWidgets('home screen with devices', (tester) async {
      final vm = MockHomeViewModel();
      getIt.registerSingleton<HomeViewModel>(vm);
      getIt.registerSingleton<SecureStorageService>(MockSecureStorageService());
      getIt.registerSingleton<TapoService>(MockTapoService());

      vm.setDevices([
        const TapoDevice(
          ip: '192.168.1.10',
          nickname: 'Lampe Salon',
          model: 'P110',
          deviceOn: true,
          isOnline: true,
        ),
        const TapoDevice(
          ip: '192.168.1.11',
          nickname: 'Bureau',
          model: 'P100',
          deviceOn: false,
          isOnline: true,
        ),
        const TapoDevice(
          ip: '192.168.1.12',
          nickname: 'Chambre',
          model: 'P110',
          deviceOn: false,
          isOnline: false,
        ),
      ]);

      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
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

      await tester.pumpWidget(const MaterialApp(home: ConfigScreen()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/config_screen.png'),
      );
    });
  });
}
