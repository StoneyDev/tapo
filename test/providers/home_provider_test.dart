import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/providers/auth_provider.dart';
import 'package:tapo/providers/home_provider.dart';

import '../helpers/providers.dart';
import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

const String _ip = TestFixtures.testDeviceIp;
const String _ip2 = TestFixtures.testDeviceIp2;

void main() {
  late MockSecureStorageService storage;
  late MockTapoService tapo;
  late MockWidgetDataService widgetData;
  late ProviderContainer container;

  setUp(() {
    storage = stubbedStorage();
    tapo = MockTapoService();
    widgetData = stubbedWidgetData();
    stubSignedIn(storage);
    when(storage.getDeviceIps()).thenAnswer((_) async => [_ip]);
    when(
      tapo.getDeviceState(_ip),
    ).thenAnswer((_) async => TestFixtures.onlineDevice());
    when(tapo.disconnect(any)).thenAnswer((_) async {});
    container = ProviderContainer.test(
      overrides: appOverrides(
        storage: storage,
        tapo: tapo,
        widgetData: widgetData,
      ),
    );
  });

  HomeState state() => container.read(homeProvider);

  Future<HomeNotifier> signedOut() async {
    stubSignedOut(storage);
    await container.read(authProvider.future);
    return container.read<HomeNotifier>(homeProvider.notifier);
  }

  group('HomeNotifier', () {
    group('first load', () {
      test('loads every plug of the signed-in account', () async {
        when(storage.getDeviceIps()).thenAnswer((_) async => [_ip, _ip2]);
        when(
          tapo.getDeviceState(_ip2),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(ip: _ip2));

        await signIn(container);

        expect(state().devices.map((d) => d.ip), [_ip, _ip2]);
        verify(tapo.getDeviceState(_ip)).called(1);
        verify(tapo.getDeviceState(_ip2)).called(1);
      });

      test('shows the spinner until the plugs are loaded', () async {
        bool? loadingDuringFetch;
        when(storage.getDeviceIps()).thenAnswer((_) async {
          loadingDuringFetch = state().isLoading;
          return [_ip];
        });

        await signIn(container);

        expect(loadingDuringFetch, isTrue);
        expect(state().isLoading, isFalse);
      });

      test('loads nothing while signed out', () async {
        await signedOut();
        await pumpEventQueue();

        expect(state(), const HomeState());
        verifyNever(storage.getDeviceIps());
      });
    });

    group('loadDevices', () {
      test('handles empty IP list', () async {
        when(storage.getDeviceIps()).thenAnswer((_) async => []);

        await signIn(container);

        expect(state().devices, isEmpty);
        expect(state().errorMessage, isNull);
        verifyNever(tapo.getDeviceState(any));
        verifyNever(widgetData.saveAllDevices(any));
      });

      test('sets errorMessage on exception', () async {
        when(storage.getDeviceIps()).thenThrow(Exception('Storage error'));

        await signIn(container);

        expect(state().errorMessage, 'Failed to load devices');
      });

      test('syncs widget data after loading devices', () async {
        await signIn(container);

        verify(widgetData.saveAllDevices([TestFixtures.onlineDevice()]));
      });

      test('reports a missing account', () async {
        final home = await signedOut();

        await home.loadDevices();

        expect(state().errorMessage, 'Not authenticated');
        expect(state().devices, isEmpty);
      });

      test('clears errorMessage on a successful load', () async {
        when(storage.getDeviceIps()).thenThrow(Exception('Error'));
        final home = await signIn(container);
        expect(state().errorMessage, isNotNull);

        when(storage.getDeviceIps()).thenAnswer((_) async => []);
        await home.loadDevices();

        expect(state().errorMessage, isNull);
      });

      test(
        'refreshes again immediately after Wi-Fi becomes available',
        () async {
          when(
            tapo.getDeviceState(_ip),
          ).thenAnswer((_) async => TestFixtures.offlineDevice());
          final home = await signIn(container);
          expect(state().devices.first.isOnline, isFalse);

          when(
            tapo.getDeviceState(_ip),
          ).thenAnswer((_) async => TestFixtures.onlineDevice());
          await home.refresh();

          expect(state().devices.first.isOnline, isTrue);
        },
      );
    });

    group('toggleDevice', () {
      late HomeNotifier home;

      setUp(() async {
        home = await signIn(container);
      });

      test('sends the toggle and shows the new state', () async {
        when(
          tapo.toggleDevice(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        await home.toggleDevice(_ip);

        verify(tapo.toggleDevice(_ip)).called(1);
        expect(state().devices.first.deviceOn, isFalse);
      });

      test('marks the plug as toggling while the command runs', () async {
        bool? togglingDuringCommand;
        when(tapo.toggleDevice(_ip)).thenAnswer((_) async {
          togglingDuringCommand = state().isToggling(_ip);
          return TestFixtures.onlineDevice(deviceOn: false);
        });

        await home.toggleDevice(_ip);

        expect(togglingDuringCommand, isTrue);
        expect(state().isToggling(_ip), isFalse);
      });

      test('ignores toggle for unknown device IP', () async {
        await home.toggleDevice('10.0.0.1');

        verifyNever(tapo.toggleDevice(any));
      });

      test('rate limits rapid toggles', () async {
        when(
          tapo.toggleDevice(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        await home.toggleDevice(_ip);
        // Immediate second toggle should be ignored
        await home.toggleDevice(_ip);

        verify(tapo.toggleDevice(_ip)).called(1);
      });

      test('syncs widget data after toggle', () async {
        when(
          tapo.toggleDevice(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        await home.toggleDevice(_ip);

        verify(
          widgetData.saveDeviceState(
            ip: _ip,
            model: 'P110',
            nickname: 'Test Plug',
            deviceOn: false,
          ),
        ).called(1);
      });

      test('sets errorMessage on exception', () async {
        when(tapo.toggleDevice(_ip)).thenThrow(Exception('Toggle failed'));

        await home.toggleDevice(_ip);

        expect(state().errorMessage, 'Failed to toggle device');
        expect(state().isToggling(_ip), isFalse);
      });

      test('clears errorMessage on successful toggle', () async {
        // A failed reload keeps the plugs on screen with an error.
        when(storage.getDeviceIps()).thenThrow(Exception('Error'));
        await home.loadDevices();
        expect(state().errorMessage, isNotNull);
        when(
          tapo.toggleDevice(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        await home.toggleDevice(_ip);

        expect(state().errorMessage, isNull);
      });

      test('is true when the plug answered', () async {
        when(
          tapo.toggleDevice(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        expect(await home.toggleDevice(_ip), isTrue);
      });

      test('is false when the plug went offline', () async {
        when(
          tapo.toggleDevice(_ip),
        ).thenAnswer((_) async => TestFixtures.offlineDevice());

        expect(await home.toggleDevice(_ip), isFalse);
      });

      test('is false when the request failed', () async {
        when(tapo.toggleDevice(_ip)).thenThrow(Exception('timeout'));

        expect(await home.toggleDevice(_ip), isFalse);
      });
    });

    test('toggleDevice reports a missing account', () async {
      final home = await signedOut();

      expect(await home.toggleDevice(_ip), isFalse);
      expect(state().errorMessage, 'Not authenticated');
    });

    group('power-off countdown', () {
      late HomeNotifier home;

      setUp(() async {
        container = ProviderContainer.test(
          overrides: [
            ...appOverrides(storage: storage, tapo: tapo),
            homeProvider.overrideWith(
              () => HomeNotifier(
                powerOffDelay: const Duration(milliseconds: 30),
                countdownTick: const Duration(milliseconds: 5),
              ),
            ),
          ],
        );
        home = await signIn(container);
      });

      test('turns the device off when countdown ends', () async {
        when(
          tapo.setDevicePower(_ip, on: false),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));

        home.schedulePowerOff(_ip);
        expect(
          state().powerOffRemaining[_ip],
          const Duration(milliseconds: 30),
        );

        await Future<void>.delayed(const Duration(milliseconds: 80));

        verify(tapo.setDevicePower(_ip, on: false)).called(1);
        expect(state().devices.first.deviceOn, isFalse);
        expect(state().powerOffRemaining, isEmpty);
      });

      test('counts down on each tick', () async {
        home.schedulePowerOff(_ip);

        await Future<void>.delayed(const Duration(milliseconds: 12));

        expect(
          state().powerOffRemaining[_ip],
          lessThan(const Duration(milliseconds: 30)),
        );
        home.cancelPowerOff(_ip);
      });

      test('cancels a scheduled countdown', () async {
        home
          ..schedulePowerOff(_ip)
          ..cancelPowerOff(_ip);

        await Future<void>.delayed(const Duration(milliseconds: 60));

        verifyNever(tapo.setDevicePower(any, on: anyNamed('on')));
        expect(state().powerOffRemaining, isEmpty);
      });

      test('does not schedule for a device that is already off', () async {
        when(
          tapo.getDeviceState(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));
        await home.loadDevices();

        home.schedulePowerOff(_ip);

        expect(state().powerOffRemaining, isEmpty);
      });

      test('signing out stops the countdowns', () async {
        home.schedulePowerOff(_ip);

        await container.read(authProvider.notifier).logout();
        await Future<void>.delayed(const Duration(milliseconds: 60));

        verifyNever(tapo.setDevicePower(any, on: anyNamed('on')));
        expect(state(), const HomeState());
      });
    });

    group('signing out', () {
      test('clears the plugs of the previous account', () async {
        await signIn(container);

        await container.read(authProvider.notifier).logout();

        expect(state(), const HomeState());
      });

      test(
        'leaves no plug in the widgets for a load ending meanwhile',
        () async {
          final home = await signIn(container);
          final plugState = Completer<TapoDevice>();
          when(tapo.getDeviceState(_ip)).thenAnswer((_) => plugState.future);
          final clearing = Completer<void>();
          when(widgetData.clearWidgetData()).thenAnswer((_) => clearing.future);
          clearInteractions(widgetData);

          final load = home.refresh(silent: true);
          await pumpEventQueue();
          final logout = container.read(authProvider.notifier).logout();
          await pumpEventQueue();
          plugState.complete(TestFixtures.onlineDevice());
          await load;
          clearing.complete();
          await logout;

          verifyNever(widgetData.saveAllDevices(any));
          verify(widgetData.clearWidgetData()).called(1);
        },
      );

      test('drops a toggle that ends afterwards', () async {
        final home = await signIn(container);
        final toggled = Completer<TapoDevice>();
        when(tapo.toggleDevice(_ip)).thenAnswer((_) => toggled.future);

        final toggle = home.toggleDevice(_ip);
        await container.read(authProvider.notifier).logout();
        toggled.complete(TestFixtures.onlineDevice(deviceOn: false));
        await toggle;

        expect(state(), const HomeState());
        verifyNever(
          widgetData.saveDeviceState(
            ip: anyNamed('ip'),
            model: anyNamed('model'),
            nickname: anyNamed('nickname'),
            deviceOn: anyNamed('deviceOn'),
            isOnline: anyNamed('isOnline'),
          ),
        );
      });
    });

    group('removeDevice', () {
      test('removes device from local list and storage, '
          'disconnects session', () async {
        final home = await signIn(container);

        await home.removeDevice(_ip);

        expect(state().devices, isEmpty);
        verify(storage.saveDeviceIps([])).called(1);
        verify(tapo.disconnect(_ip)).called(1);
        verify(widgetData.saveAllDevices([])).called(1);
      });
    });

    group('updateDeviceIp', () {
      const newIp = '192.168.1.200';
      late HomeNotifier home;

      setUp(() async {
        when(storage.getDeviceIps()).thenAnswer((_) async => [_ip, _ip2]);
        when(
          tapo.getDeviceState(_ip2),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(ip: _ip2));
        when(
          tapo.getDeviceState(newIp),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(ip: newIp));
        home = await signIn(container);
        clearInteractions(storage);
      });

      test('replaces IP in storage and reloads devices', () async {
        await home.updateDeviceIp(_ip, newIp);

        verify(storage.saveDeviceIps([newIp, _ip2])).called(1);
        verify(storage.getDeviceIps()).called(2);
      });

      test('disconnects old IP session', () async {
        await home.updateDeviceIp(_ip, newIp);

        verify(tapo.disconnect(_ip)).called(1);
      });

      test('does nothing when oldIp not found', () async {
        await home.updateDeviceIp('10.0.0.99', '10.0.0.100');

        verifyNever(storage.saveDeviceIps(any));
        verifyNever(tapo.disconnect(any));
      });

      test('sets error and does not save when newIp already exists', () async {
        await home.updateDeviceIp(_ip, _ip2);

        expect(state().errorMessage, 'IP address already exists');
        verifyNever(storage.saveDeviceIps(any));
        verifyNever(tapo.disconnect(any));
      });
    });

    group('silent refresh', () {
      late HomeNotifier home;

      setUp(() async {
        home = await signIn(container);
      });

      test('keeps devices visible without a spinner while fetching', () async {
        bool? loadingDuringFetch;
        int? devicesDuringFetch;
        when(storage.getDeviceIps()).thenAnswer((_) async {
          loadingDuringFetch = state().isLoading;
          devicesDuringFetch = state().devices.length;
          return [_ip];
        });

        await home.refresh(silent: true);

        expect(loadingDuringFetch, isFalse);
        expect(devicesDuringFetch, 1);
      });

      test('keeps previous devices and no error when it fails', () async {
        when(storage.getDeviceIps()).thenThrow(Exception('boom'));

        await home.refresh(silent: true);

        expect(state().devices.single.ip, _ip);
        expect(state().errorMessage, isNull);
      });

      test('joins a load that is already in flight', () async {
        final ips = Completer<List<String>>();
        when(storage.getDeviceIps()).thenAnswer((_) => ips.future);
        clearInteractions(storage);

        final first = home.loadDevices();
        final second = home.refresh(silent: true);
        ips.complete([_ip]);
        await Future.wait([first, second]);

        verify(storage.getDeviceIps()).called(1);
      });
    });

    group('refreshIfStale', () {
      test('skips the reload when the last load is recent', () async {
        final home = await signIn(container);
        clearInteractions(storage);

        await home.refreshIfStale(const Duration(hours: 1));

        verifyNever(storage.getDeviceIps());
      });

      test('reloads when the last load is older than maxAge', () async {
        final home = await signIn(container);
        clearInteractions(storage);

        await home.refreshIfStale(Duration.zero);

        verify(storage.getDeviceIps()).called(1);
      });

      test('retries after a failed load', () async {
        when(storage.getDeviceIps()).thenThrow(Exception('boom'));
        final home = await signIn(container);
        when(storage.getDeviceIps()).thenAnswer((_) async => [_ip]);

        await home.refreshIfStale(const Duration(hours: 1));

        expect(state().devices, hasLength(1));
      });
    });

    group('turnOffAll', () {
      const offlineIp = '192.168.1.102';
      late HomeNotifier home;

      setUp(() async {
        when(
          storage.getDeviceIps(),
        ).thenAnswer((_) async => [_ip, _ip2, offlineIp]);
        when(tapo.getDeviceState(_ip2)).thenAnswer(
          (_) async => TestFixtures.onlineDevice(ip: _ip2, deviceOn: false),
        );
        when(
          tapo.getDeviceState(offlineIp),
        ).thenAnswer((_) async => TestFixtures.offlineDevice(ip: offlineIp));
        when(
          tapo.setDevicePower(_ip, on: false),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));
        home = await signIn(container);
      });

      test('turns off only the online devices that are on', () async {
        await home.turnOffAll();

        verify(tapo.setDevicePower(_ip, on: false)).called(1);
        verifyNever(tapo.setDevicePower(_ip2, on: anyNamed('on')));
        verifyNever(tapo.setDevicePower(offlineIp, on: anyNamed('on')));
        expect(state().devices.first.deviceOn, isFalse);
      });

      test('cancels scheduled power-off countdowns', () async {
        home.schedulePowerOff(_ip);

        await home.turnOffAll();

        expect(state().powerOffRemaining, isEmpty);
      });
    });

    group('concurrent loads', () {
      late HomeNotifier home;

      setUp(() async {
        when(storage.getDeviceIps()).thenAnswer((_) async => [_ip, _ip2]);
        when(
          tapo.getDeviceState(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice(deviceOn: false));
        when(tapo.getDeviceState(_ip2)).thenAnswer(
          (_) async => TestFixtures.onlineDevice(ip: _ip2, deviceOn: false),
        );
        home = await signIn(container);
      });

      test('a normal refresh starts a new load while one is running', () async {
        final pending = Completer<List<String>>();
        when(storage.getDeviceIps()).thenAnswer((_) => pending.future);
        clearInteractions(storage);

        final first = home.refresh(silent: true);
        final second = home.refresh();
        pending.complete([_ip]);
        await Future.wait([first, second]);

        verify(storage.getDeviceIps()).called(2);
      });

      test('an outdated load does not overwrite a newer one', () async {
        final slowState = Completer<TapoDevice>();
        when(tapo.getDeviceState(_ip)).thenAnswer((_) => slowState.future);
        final outdated = home.loadDevices(silent: true);
        await pumpEventQueue();

        when(
          tapo.getDeviceState(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice());
        await home.refresh();
        slowState.complete(TestFixtures.offlineDevice());
        await outdated;

        expect(state().devices.first.isOnline, isTrue);
      });

      test(
        'a silent load ending keeps the spinner of a running load',
        () async {
          final silentIps = Completer<List<String>>();
          final normalIps = Completer<List<String>>();
          final answers = [silentIps, normalIps];
          when(
            storage.getDeviceIps(),
          ).thenAnswer((_) => answers.removeAt(0).future);

          final silent = home.refresh(silent: true);
          final normal = home.loadDevices();
          silentIps.complete([_ip]);
          await silent;

          expect(state().isLoading, isTrue);
          normalIps.complete([_ip]);
          await normal;
        },
      );

      test('a toggle finished during a load is not overwritten', () async {
        final staleState = Completer<TapoDevice>();
        when(tapo.getDeviceState(_ip)).thenAnswer((_) => staleState.future);
        when(
          tapo.toggleDevice(_ip),
        ).thenAnswer((_) async => TestFixtures.onlineDevice());

        final load = home.refresh(silent: true);
        await pumpEventQueue();
        await home.toggleDevice(_ip);
        staleState.complete(TestFixtures.onlineDevice(deviceOn: false));
        await load;

        expect(state().devices.first.deviceOn, isTrue);
      });

      test('a plug removed during a load does not come back', () async {
        final slowState = Completer<TapoDevice>();
        when(tapo.getDeviceState(_ip)).thenAnswer((_) => slowState.future);

        final load = home.refresh(silent: true);
        await pumpEventQueue();
        await home.removeDevice(_ip2);
        slowState.complete(TestFixtures.onlineDevice(deviceOn: false));
        await load;

        expect(state().devices.map((d) => d.ip), [_ip]);
      });
    });
  });
}
