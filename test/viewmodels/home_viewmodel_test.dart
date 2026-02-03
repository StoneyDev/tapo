import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';

import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

void main() {
  late MockSecureStorageService mockStorageService;
  late MockTapoService mockTapoService;
  late MockWidgetDataService mockWidgetDataService;
  late HomeViewModel viewModel;
  final getIt = GetIt.instance;

  setUp(() async {
    // Reset GetIt first
    await getIt.reset();

    mockStorageService = MockSecureStorageService();
    mockTapoService = MockTapoService();
    mockWidgetDataService = MockWidgetDataService();

    // Register mocks BEFORE creating ViewModel
    getIt
      ..registerSingleton<SecureStorageService>(mockStorageService)
      ..registerSingleton<TapoService>(mockTapoService)
      ..registerSingleton<WidgetDataService>(mockWidgetDataService);

    // Stub widget data service methods by default
    when(mockWidgetDataService.saveAllDevices(any)).thenAnswer((_) async {});
    when(mockWidgetDataService.saveDeviceState(
      ip: anyNamed('ip'),
      model: anyNamed('model'),
      deviceOn: anyNamed('deviceOn'),
      isOnline: anyNamed('isOnline'),
    )).thenAnswer((_) async {});

    // Now create ViewModel - it will use the registered mocks
    viewModel = HomeViewModel();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('HomeViewModel', () {
    group('constructor', () {
      test('initializes with default state', () {
        expect(viewModel.devices, isEmpty);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, isNull);
      });
    });

    group('loadDevices', () {
      test('fetches IPs from storage and device states from service',
          () async {
        when(mockStorageService.getDeviceIps()).thenAnswer(
          (_) async => [TestFixtures.testDeviceIp],
        );
        when(mockTapoService.getDeviceState(
          TestFixtures.testDeviceIp,
        )).thenAnswer(
          (_) async => TestFixtures.onlineDevice(),
        );

        await viewModel.loadDevices();

        expect(viewModel.devices.length, 1);
        expect(
          viewModel.devices.first.ip,
          TestFixtures.testDeviceIp,
        );
        verify(mockStorageService.getDeviceIps())
            .called(1);
        verify(mockTapoService.getDeviceState(
          TestFixtures.testDeviceIp,
        )).called(1);
      });

      test('fetches multiple devices in parallel',
          () async {
        when(mockStorageService.getDeviceIps()).thenAnswer(
          (_) async => [
            TestFixtures.testDeviceIp,
            TestFixtures.testDeviceIp2,
          ],
        );
        when(mockTapoService.getDeviceState(
          TestFixtures.testDeviceIp,
        )).thenAnswer(
          (_) async => TestFixtures.onlineDevice(),
        );
        when(mockTapoService.getDeviceState(
          TestFixtures.testDeviceIp2,
        )).thenAnswer(
          (_) async => TestFixtures.onlineDevice(
            ip: TestFixtures.testDeviceIp2,
          ),
        );

        await viewModel.loadDevices();

        expect(viewModel.devices.length, 2);
        verify(mockTapoService.getDeviceState(
          TestFixtures.testDeviceIp,
        )).called(1);
        verify(mockTapoService.getDeviceState(
          TestFixtures.testDeviceIp2,
        )).called(1);
      });

      test('handles empty IP list', () async {
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        await viewModel.loadDevices();

        expect(viewModel.devices, isEmpty);
        expect(viewModel.errorMessage, isNull);
        verifyNever(mockTapoService.getDeviceState(any));
      });

      test('sets isLoading true during fetch, false after',
          () async {
        var loadingDuringFetch = false;
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async {
          loadingDuringFetch = viewModel.isLoading;
          return [];
        });

        await viewModel.loadDevices();

        expect(loadingDuringFetch, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('sets errorMessage when TapoService not registered',
          () async {
        // Create new ViewModel without TapoService registered
        await getIt.reset();
        getIt
          ..registerSingleton<SecureStorageService>(
            mockStorageService,
          )
          ..registerSingleton<WidgetDataService>(
            mockWidgetDataService,
          );
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

      test('syncs widget data after loading devices', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());

        await viewModel.loadDevices();

        verify(mockWidgetDataService.saveAllDevices(any)).called(1);
      });

      test('does not sync widget data when no devices', () async {
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        await viewModel.loadDevices();

        verifyNever(mockWidgetDataService.saveAllDevices(any));
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

        // Make toggleDevice take time so we can check isToggling
        var wasToggling = false;
        when(mockTapoService.toggleDevice(
          TestFixtures.testDeviceIp,
        )).thenAnswer((_) async {
          wasToggling = viewModel.isToggling(
            TestFixtures.testDeviceIp,
          );
          return TestFixtures.onlineDevice(deviceOn: false);
        });

        await viewModel.toggleDevice(
          TestFixtures.testDeviceIp,
        );

        expect(wasToggling, isTrue);
        expect(
          viewModel.isToggling(TestFixtures.testDeviceIp),
          isFalse,
        );
      });
    });

    group('toggleDevice', () {
      setUp(() async {
        when(mockStorageService.getDeviceIps()).thenAnswer(
          (_) async => [TestFixtures.testDeviceIp],
        );
        when(mockTapoService.getDeviceState(
          TestFixtures.testDeviceIp,
        )).thenAnswer(
          (_) async => TestFixtures.onlineDevice(),
        );
        await viewModel.loadDevices();
      });

      test('calls TapoService.toggleDevice', () async {
        when(mockTapoService.toggleDevice(
          TestFixtures.testDeviceIp,
        )).thenAnswer(
          (_) async =>
              TestFixtures.onlineDevice(deviceOn: false),
        );

        await viewModel.toggleDevice(
          TestFixtures.testDeviceIp,
        );

        verify(mockTapoService.toggleDevice(
          TestFixtures.testDeviceIp,
        )).called(1);
      });

      test('updates device in list with toggled state',
          () async {
        expect(viewModel.devices.first.deviceOn, isTrue);

        when(mockTapoService.toggleDevice(
          TestFixtures.testDeviceIp,
        )).thenAnswer(
          (_) async =>
              TestFixtures.onlineDevice(deviceOn: false),
        );

        await viewModel.toggleDevice(
          TestFixtures.testDeviceIp,
        );

        expect(viewModel.devices.first.deviceOn, isFalse);
      });

      test('notifies listeners at start and end of toggle',
          () async {
        when(mockTapoService.toggleDevice(
          TestFixtures.testDeviceIp,
        )).thenAnswer(
          (_) async =>
              TestFixtures.onlineDevice(deviceOn: false),
        );

        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        await viewModel.toggleDevice(TestFixtures.testDeviceIp);

        // Should notify when toggling starts and when it finishes
        expect(notificationCount, 2);
      });

      test('sets errorMessage when TapoService not registered',
          () async {
        // Create new ViewModel without TapoService registered
        await getIt.reset();
        getIt
          ..registerSingleton<SecureStorageService>(
            mockStorageService,
          )
          ..registerSingleton<WidgetDataService>(
            mockWidgetDataService,
          );
        // Need TapoService temporarily to load devices
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
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
        when(mockTapoService.toggleDevice(
          TestFixtures.testDeviceIp,
        )).thenAnswer(
          (_) async =>
              TestFixtures.onlineDevice(deviceOn: false),
        );

        // First toggle should work
        await viewModel.toggleDevice(
          TestFixtures.testDeviceIp,
        );
        // Immediate second toggle should be ignored
        await viewModel.toggleDevice(
          TestFixtures.testDeviceIp,
        );

        verify(mockTapoService.toggleDevice(
          TestFixtures.testDeviceIp,
        )).called(1);
      });

      test('syncs widget data after toggle', () async {
        when(mockTapoService.toggleDevice(
          TestFixtures.testDeviceIp,
        )).thenAnswer(
          (_) async =>
              TestFixtures.onlineDevice(deviceOn: false),
        );

        await viewModel.toggleDevice(TestFixtures.testDeviceIp);

        verify(mockWidgetDataService.saveDeviceState(
          ip: TestFixtures.testDeviceIp,
          model: 'P110',
          deviceOn: false,
        )).called(1);
      });

      test('removes device from togglingDevices on exception', () async {
        when(mockTapoService.toggleDevice(TestFixtures.testDeviceIp))
            .thenThrow(Exception('Toggle failed'));

        // Exception bubbles up but finally block should still run
        try {
          await viewModel.toggleDevice(
            TestFixtures.testDeviceIp,
          );
        } on Exception {
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
        when(mockStorageService.saveDeviceIps(any))
            .thenAnswer((_) async {});
        when(mockTapoService.disconnect(
          TestFixtures.testDeviceIp,
        )).thenReturn(null);
        await viewModel.loadDevices();
      });

      test(
          'removes device from local list and storage, '
          'disconnects session', () async {
        expect(viewModel.devices.length, 1);

        var notified = false;
        viewModel.addListener(() => notified = true);

        await viewModel.removeDevice(
          TestFixtures.testDeviceIp,
        );

        expect(viewModel.devices, isEmpty);
        verify(mockStorageService.saveDeviceIps([]))
            .called(1);
        verify(mockTapoService.disconnect(
          TestFixtures.testDeviceIp,
        )).called(1);
        expect(notified, isTrue);
      });
    });

    group('refresh', () {
      test('delegates to loadDevices', () async {
        when(mockStorageService.getDeviceIps())
            .thenAnswer((_) async => [TestFixtures.testDeviceIp]);
        when(mockTapoService.getDeviceState(TestFixtures.testDeviceIp))
            .thenAnswer((_) async => TestFixtures.onlineDevice());

        await viewModel.refresh();

        verify(mockStorageService.getDeviceIps()).called(1);
        expect(viewModel.devices.length, 1);
      });
    });

    group('error handling', () {
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

  });
}
