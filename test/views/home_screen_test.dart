import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/views/home_screen.dart';
import 'package:tapo/views/widgets/plug_card.dart';

import '../helpers/test_utils.dart';

/// Mock HomeViewModel for widget testing
/// Note: This tests UI behavior in response to ViewModel state changes.
/// The actual ViewModel logic is tested in home_viewmodel_test.dart.
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

  // State setters
  void setDevices(List<TapoDevice> devices) {
    _devices = devices;
    notifyListeners();
  }
  void setIsLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
  void setToggling(String ip, bool toggling) {
    toggling ? _togglingDevices.add(ip) : _togglingDevices.remove(ip);
    notifyListeners();
  }

  // Call tracking
  int loadDevicesCallCount = 0;
  int refreshCallCount = 0;
  int toggleDeviceCallCount = 0;
  String? lastToggledIp;
  int removeDeviceCallCount = 0;
  String? lastRemovedIp;

  @override
  Future<void> loadDevices() async => loadDevicesCallCount++;
  @override
  Future<void> refresh() async => refreshCallCount++;
  @override
  Future<void> toggleDevice(String ip) async {
    toggleDeviceCallCount++;
    lastToggledIp = ip;
  }
  @override
  Future<void> removeDevice(String ip) async {
    removeDeviceCallCount++;
    lastRemovedIp = ip;
  }
}

/// Mock SecureStorageService for logout testing
class MockSecureStorageService implements SecureStorageService {
  int clearCredentialsCallCount = 0;
  int clearDeviceIpsCallCount = 0;

  @override
  Future<void> clearCredentials() async => clearCredentialsCallCount++;
  @override
  Future<void> clearDeviceIps() async => clearDeviceIpsCallCount++;
  @override
  Future<({String? email, String? password})> getCredentials() async =>
      (email: null, password: null);
  @override
  Future<List<String>> getDeviceIps() async => [];
  @override
  Future<bool> hasCredentials() async => false;
  @override
  Future<void> saveCredentials(String email, String password) async {}
  @override
  Future<void> saveDeviceIps(List<String> ips) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock TapoService for logout testing
class MockTapoService implements TapoService {
  int disconnectAllCallCount = 0;

  @override
  void disconnectAll() => disconnectAllCallCount++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockHomeViewModel mockViewModel;
  late MockSecureStorageService mockStorageService;
  late MockTapoService mockTapoService;
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
    mockViewModel = MockHomeViewModel();
    mockStorageService = MockSecureStorageService();
    mockTapoService = MockTapoService();

    getIt.registerSingleton<HomeViewModel>(mockViewModel);
    getIt.registerSingleton<SecureStorageService>(mockStorageService);
    getIt.registerSingleton<TapoService>(mockTapoService);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildTestWidget({bool withNavigation = false}) {
    if (withNavigation) {
      return MaterialApp(
        initialRoute: '/home',
        routes: {
          '/home': (_) => const HomeScreen(),
          '/config': (_) => const Scaffold(body: Text('Config Screen')),
        },
      );
    }
    return const MaterialApp(
      home: HomeScreen(),
    );
  }

  group('HomeScreen', () {
    group('loading state', () {
      testWidgets('shows spinner when loading, hides otherwise', (tester) async {
        mockViewModel.setIsLoading(true);
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        mockViewModel.setIsLoading(false);
        mockViewModel.setDevices([]);
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('device list', () {
      testWidgets('renders PlugCards for each device', (tester) async {
        mockViewModel.setDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1', nickname: 'Device 1'),
          TestFixtures.onlineDevice(ip: '10.0.0.2', nickname: 'Device 2'),
        ]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(PlugCard), findsNWidgets(2));
        expect(find.text('Device 1'), findsOneWidget);
        expect(find.text('Device 2'), findsOneWidget);
      });

      testWidgets('displays empty state message when no devices', (tester) async {
        mockViewModel.setDevices([]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('No devices configured'), findsOneWidget);
      });

      testWidgets('displays error message with retry button', (tester) async {
        mockViewModel.setErrorMessage('Connection failed');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Connection failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('retry button calls refresh', (tester) async {
        mockViewModel.setErrorMessage('Error');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(mockViewModel.refreshCallCount, 1);
      });
    });

    group('pull to refresh', () {
      testWidgets('pull down triggers refresh', (tester) async {
        mockViewModel.setDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1'),
        ]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Perform pull to refresh
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pumpAndSettle();

        expect(mockViewModel.refreshCallCount, 1);
      });
    });

    group('logout', () {
      testWidgets('clears credentials, disconnects, navigates to config', (tester) async {
        mockViewModel.setDevices([]);
        await tester.pumpWidget(buildTestWidget(withNavigation: true));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.logout), findsOneWidget);

        await tester.tap(find.byIcon(Icons.logout));
        await tester.pumpAndSettle();

        expect(mockStorageService.clearCredentialsCallCount, 1);
        expect(mockStorageService.clearDeviceIpsCallCount, 1);
        expect(mockTapoService.disconnectAllCallCount, 1);
        expect(find.text('Config Screen'), findsOneWidget);
      });
    });

    group('device interactions', () {
      testWidgets('device toggle triggers toggleDevice', (tester) async {
        mockViewModel.setDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1', deviceOn: false),
        ]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap the switch to toggle
        await tester.tap(find.byType(Switch));
        await tester.pump();

        expect(mockViewModel.toggleDeviceCallCount, 1);
        expect(mockViewModel.lastToggledIp, '10.0.0.1');
      });

      testWidgets('isToggling state passed to PlugCard', (tester) async {
        mockViewModel.setDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1'),
        ]);
        mockViewModel.setToggling('10.0.0.1', true);
        await tester.pumpWidget(buildTestWidget());
        // Use pump() instead of pumpAndSettle() because CircularProgressIndicator animates indefinitely
        await tester.pump();

        // When toggling, PlugCard shows spinner instead of switch
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Switch), findsNothing);
      });
    });

    group('app lifecycle', () {
      testWidgets('app resume triggers refresh', (tester) async {
        mockViewModel.setDevices([]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Reset count since loadDevices is called in initState
        mockViewModel.refreshCallCount = 0;

        // Simulate app resume
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();

        expect(mockViewModel.refreshCallCount, 1);
      });
    });

    group('initialization', () {
      testWidgets('renders title and calls loadDevices', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.text('Tapo Devices'), findsOneWidget);
        expect(mockViewModel.loadDevicesCallCount, 1);
      });
    });
  });
}
