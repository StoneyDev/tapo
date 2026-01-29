import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';

import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

void main() {
  late MockSecureStorageService mockStorageService;
  late MockTapoService mockTapoService;
  late HomeViewModel viewModel;
  final getIt = GetIt.instance;

  setUp(() async {
    // Reset GetIt first
    await getIt.reset();

    mockStorageService = MockSecureStorageService();
    mockTapoService = MockTapoService();

    // Register mocks BEFORE creating ViewModel
    getIt.registerSingleton<SecureStorageService>(mockStorageService);
    getIt.registerSingleton<TapoService>(mockTapoService);

    // Now create ViewModel - it will use the registered mocks
    viewModel = HomeViewModel();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('HomeViewModel', () {
    group('constructor', () {
      test('creates instance', () {
        expect(viewModel, isNotNull);
        expect(viewModel, isA<HomeViewModel>());
      });

      test('initializes with empty devices', () {
        expect(viewModel.devices, isEmpty);
      });

      test('initializes with isLoading false', () {
        expect(viewModel.isLoading, isFalse);
      });

      test('initializes with errorMessage null', () {
        expect(viewModel.errorMessage, isNull);
      });
    });

    group('loadDevices', () {
      test('fetches IPs from storage and device states from service', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());

        await viewModel.loadDevices();

        expect(viewModel.devices.length, 1);
        expect(viewModel.devices.first.ip, TestFixtures.testDeviceIp);
        verify(mockStorageService.getDeviceIps()).called(1);
        verify(mockTapoService.getDeviceState(TestFixtures.testDeviceIp)).called(1);
      });

      test('fetches multiple devices in parallel', () async {
        when(mockStorageService.getDeviceIps()).thenAnswer(
            (_) async => [TestFixtures.testDeviceIp, TestFixtures.testDeviceIp2]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp2))
            .thenAnswer((_) async =>
                TestFixtures.onlineDevice(ip: TestFixtures.testDeviceIp2));

        await viewModel.loadDevices();

        expect(viewModel.devices.length, 2);
        verify(mockTapoService.getDeviceState(TestFixtures.testDeviceIp)).called(1);
        verify(mockTapoService.getDeviceState(TestFixtures.testDeviceIp2)).called(1);
      });

      test('handles empty IP list', () async {
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        await viewModel.loadDevices();

        expect(viewModel.devices, isEmpty);
        expect(viewModel.errorMessage, isNull);
        verifyNever(mockTapoService.getDeviceState(any));
      });

      test('notifies listeners when loading starts and finishes', () async {
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        final notifications = <bool>[];
        viewModel.addListener(() {
          notifications.add(viewModel.isLoading);
        });

        await viewModel.loadDevices();

        // Should notify: loading=true, then loading=false (empty case notifies twice at end)
        expect(notifications.contains(true), isTrue);
        expect(notifications.last, isFalse);
      });

      test('sets isLoading true during load', () async {
        bool loadingDuringFetch = false;
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async {
          loadingDuringFetch = viewModel.isLoading;
          return [];
        });

        await viewModel.loadDevices();

        expect(loadingDuringFetch, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('sets errorMessage when TapoService not registered', () async {
        // Create new ViewModel without TapoService registered
        await getIt.reset();
        getIt.registerSingleton<SecureStorageService>(mockStorageService);
        // Intentionally not registering TapoService
        final vmWithoutTapo = HomeViewModel();

        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);

        await vmWithoutTapo.loadDevices();

        expect(vmWithoutTapo.errorMessage, 'Not authenticated');
        expect(vmWithoutTapo.devices, isEmpty);
      });

      test('sets errorMessage on exception', () async {
        when(mockStorageService.getDeviceIps())
            .thenThrow(Exception('Storage error'));

        await viewModel.loadDevices();

        expect(viewModel.errorMessage, 'Failed to load devices');
      });
    });

    group('isToggling', () {
      test('returns false for device not being toggled', () {
        expect(viewModel.isToggling(TestFixtures.testDeviceIp), isFalse);
      });

      test('returns true while device is being toggled', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());

        await viewModel.loadDevices();

        // Make toggleDevice take time so we can check isToggling during
        bool wasToggling = false;
        when(mockTapoService.toggleDevice(TestFixtures.testDeviceIp))
            .thenAnswer((_) async {
          wasToggling = viewModel.isToggling(TestFixtures.testDeviceIp);
          return TestFixtures.onlineDevice(deviceOn: false);
        });

        await viewModel.toggleDevice(TestFixtures.testDeviceIp);

        expect(wasToggling, isTrue);
        expect(viewModel.isToggling(TestFixtures.testDeviceIp), isFalse);
      });
    });

    group('toggleDevice', () {
      setUp(() async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: true));
        await viewModel.loadDevices();
      });

      test('calls TapoService.toggleDevice', () async {
        when(mockTapoService.toggleDevice(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        await viewModel.toggleDevice(TestFixtures.testDeviceIp);

        verify(mockTapoService.toggleDevice(TestFixtures.testDeviceIp)).called(1);
      });

      test('updates device in list with toggled state', () async {
        expect(viewModel.devices.first.deviceOn, isTrue);

        when(mockTapoService.toggleDevice(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        await viewModel.toggleDevice(TestFixtures.testDeviceIp);

        expect(viewModel.devices.first.deviceOn, isFalse);
      });

      test('notifies listeners at start and end of toggle', () async {
        when(mockTapoService.toggleDevice(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        int notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        await viewModel.toggleDevice(TestFixtures.testDeviceIp);

        // Should notify when toggling starts and when it finishes
        expect(notificationCount, 2);
      });

      test('sets errorMessage when TapoService not registered', () async {
        // Create new ViewModel without TapoService registered
        await getIt.reset();
        getIt.registerSingleton<SecureStorageService>(mockStorageService);
        // Intentionally not registering TapoService - but need to load devices first
        // Actually, we need devices loaded to test toggle. Let's set up properly.
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        // Re-register TapoService temporarily to load devices
        getIt.registerSingleton<TapoService>(mockTapoService);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());

        final vmWithoutTapo = HomeViewModel();
        await vmWithoutTapo.loadDevices();

        // Now unregister TapoService
        await getIt.unregister<TapoService>();

        await vmWithoutTapo.toggleDevice(TestFixtures.testDeviceIp);

        expect(vmWithoutTapo.errorMessage, 'Not authenticated');
      });

      test('ignores toggle for unknown device IP', () async {
        await viewModel.toggleDevice('10.0.0.1');

        verifyNever(mockTapoService.toggleDevice(any));
      });

      test('rate limits rapid toggles', () async {
        when(mockTapoService.toggleDevice(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        // First toggle should work
        await viewModel.toggleDevice(TestFixtures.testDeviceIp);
        // Immediate second toggle should be ignored
        await viewModel.toggleDevice(TestFixtures.testDeviceIp);

        verify(mockTapoService.toggleDevice(TestFixtures.testDeviceIp)).called(1);
      });

      test('removes device from togglingDevices on exception', () async {
        when(mockTapoService.toggleDevice(TestFixtures.testDeviceIp))
            .thenThrow(Exception('Toggle failed'));

        // Exception bubbles up but finally block should still run
        try {
          await viewModel.toggleDevice(TestFixtures.testDeviceIp);
        } catch (_) {
          // Expected
        }

        expect(viewModel.isToggling(TestFixtures.testDeviceIp), isFalse);
      });
    });

    group('removeDevice', () {
      setUp(() async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());
        await viewModel.loadDevices();
      });

      test('removes device from local list', () async {
        expect(viewModel.devices.length, 1);

        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});
        when(mockTapoService.disconnect(TestFixtures.testDeviceIp)).thenReturn(null);

        await viewModel.removeDevice(TestFixtures.testDeviceIp);

        expect(viewModel.devices, isEmpty);
      });

      test('removes IP from storage', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});
        when(mockTapoService.disconnect(TestFixtures.testDeviceIp)).thenReturn(null);

        await viewModel.removeDevice(TestFixtures.testDeviceIp);

        verify(mockStorageService.saveDeviceIps([])).called(1);
      });

      test('disconnects session', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});
        when(mockTapoService.disconnect(TestFixtures.testDeviceIp)).thenReturn(null);

        await viewModel.removeDevice(TestFixtures.testDeviceIp);

        verify(mockTapoService.disconnect(TestFixtures.testDeviceIp)).called(1);
      });

      test('notifies listeners when device removed', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});
        when(mockTapoService.disconnect(TestFixtures.testDeviceIp)).thenReturn(null);

        bool notified = false;
        viewModel.addListener(() => notified = true);

        await viewModel.removeDevice(TestFixtures.testDeviceIp);

        expect(notified, isTrue);
      });
    });

    group('refresh', () {
      test('calls loadDevices', () async {
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        await viewModel.refresh();

        verify(mockStorageService.getDeviceIps()).called(1);
      });

      test('updates devices list', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());

        await viewModel.refresh();

        expect(viewModel.devices.length, 1);
      });
    });

    group('error handling', () {
      test('errorMessage is null initially', () {
        expect(viewModel.errorMessage, isNull);
      });

      test('errorMessage set on loadDevices failure', () async {
        when(mockStorageService.getDeviceIps())
            .thenThrow(Exception('Error'));

        await viewModel.loadDevices();

        expect(viewModel.errorMessage, 'Failed to load devices');
      });

      test('errorMessage cleared on successful loadDevices', () async {
        // First trigger error
        when(mockStorageService.getDeviceIps())
            .thenThrow(Exception('Error'));
        await viewModel.loadDevices();
        expect(viewModel.errorMessage, isNotNull);

        // Then successful load
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);
        await viewModel.loadDevices();

        expect(viewModel.errorMessage, isNull);
      });

      test('errorMessage set on toggleDevice when not authenticated', () async {
        // Load devices first with TapoService registered
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());
        await viewModel.loadDevices();

        // Now unregister TapoService
        await getIt.unregister<TapoService>();

        await viewModel.toggleDevice(TestFixtures.testDeviceIp);

        expect(viewModel.errorMessage, 'Not authenticated');
      });

      test('notifies listeners when error is set', () async {
        final errors = <String?>[];
        viewModel.addListener(() {
          errors.add(viewModel.errorMessage);
        });

        when(mockStorageService.getDeviceIps())
            .thenThrow(Exception('Error'));

        await viewModel.loadDevices();

        expect(errors.contains('Failed to load devices'), isTrue);
      });
    });

    group('devices immutability', () {
      test('devices returns unmodifiable list', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());

        await viewModel.loadDevices();

        expect(
          () => viewModel.devices.add(TestFixtures.offlineDevice()),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('isLoading states', () {
      test('isLoading is false initially', () {
        expect(viewModel.isLoading, isFalse);
      });

      test('isLoading becomes true during loadDevices', () async {
        bool wasLoadingDuringCall = false;

        when(mockStorageService.getDeviceIps()).thenAnswer((_) async {
          wasLoadingDuringCall = viewModel.isLoading;
          return [];
        });

        await viewModel.loadDevices();

        expect(wasLoadingDuringCall, isTrue);
      });

      test('isLoading becomes false after loadDevices completes', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());

        await viewModel.loadDevices();

        expect(viewModel.isLoading, isFalse);
      });

      test('isLoading becomes false after loadDevices error', () async {
        when(mockStorageService.getDeviceIps())
            .thenThrow(Exception('Error'));

        await viewModel.loadDevices();

        expect(viewModel.isLoading, isFalse);
      });
    });
  });
}
