import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/services/desktop_shell.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/tray_controller.dart';
import 'package:tapo/services/widget_data_service.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/viewmodels/launch_at_startup_viewmodel.dart';

import '../helpers/fake_desktop_shell.dart';
import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

const String _salon = TestFixtures.testDeviceIp;
const String _bureau = TestFixtures.testDeviceIp2;
const _chambre = '192.168.1.102';

/// Renders a menu as text: "✓ " when checked, " (grisé)" when disabled.
List<String> _describe(List<TrayMenuEntry> entries) => [
  for (final entry in entries)
    switch (entry) {
      TrayMenuSeparator() => '---',
      TrayMenuItem(:final label, :final checked, :final enabled) =>
        '${checked ? '✓ ' : ''}$label${enabled ? '' : ' (grisé)'}',
    },
];

void main() {
  late MockSecureStorageService storage;
  late MockTapoService tapo;
  late FakeDesktopShell shell;
  late HomeViewModel home;
  late LaunchAtStartupViewModel launchAtStartup;
  late TrayController controller;
  final getIt = GetIt.instance;

  void stubStates({bool bureauOn = false}) {
    when(
      tapo.getDeviceState(_salon),
    ).thenAnswer((_) async => TestFixtures.onlineDevice(nickname: 'Salon'));
    when(tapo.getDeviceState(_bureau)).thenAnswer(
      (_) async => TestFixtures.onlineDevice(
        ip: _bureau,
        nickname: 'Bureau',
        deviceOn: bureauOn,
      ),
    );
    when(
      tapo.getDeviceState(_chambre),
    ).thenAnswer((_) async => TestFixtures.offlineDevice(ip: _chambre));
  }

  setUp(() async {
    await getIt.reset();
    storage = MockSecureStorageService();
    tapo = MockTapoService();
    final widgetData = MockWidgetDataService();
    when(widgetData.saveAllDevices(any)).thenAnswer((_) async {});
    when(widgetData.refreshWidgets()).thenAnswer((_) async {});
    when(
      widgetData.saveDeviceState(
        ip: anyNamed('ip'),
        model: anyNamed('model'),
        nickname: anyNamed('nickname'),
        deviceOn: anyNamed('deviceOn'),
        isOnline: anyNamed('isOnline'),
      ),
    ).thenAnswer((_) async {});
    getIt
      ..registerSingleton<SecureStorageService>(storage)
      ..registerSingleton<TapoService>(tapo)
      ..registerSingleton<WidgetDataService>(widgetData);

    when(
      storage.getDeviceIps(),
    ).thenAnswer((_) async => [_salon, _bureau, _chambre]);
    stubStates();

    shell = FakeDesktopShell();
    home = HomeViewModel();
    launchAtStartup = LaunchAtStartupViewModel(shell: shell);
    controller = TrayController(
      shell: shell,
      home: home,
      launchAtStartup: launchAtStartup,
      refreshBudget: const Duration(milliseconds: 50),
    );
    await controller.start();
  });

  tearDown(() async {
    home.dispose();
    launchAtStartup.dispose();
    await getIt.reset();
  });

  group('TrayController', () {
    group('menu', () {
      test('refreshes the plugs before listing them', () async {
        await home.loadDevices();
        stubStates(bureauOn: true);

        await shell.rightClickTray();

        expect(_describe(shell.menus.single), [
          'Tapo · 2/3 allumées (grisé)',
          '---',
          '✓ Salon',
          '✓ Bureau',
          'Unknown — hors ligne (grisé)',
          '---',
          'Tout éteindre',
          '---',
          'Ouvrir Tapo',
          'Lancer au démarrage',
          'Quitter',
        ]);
      });

      test('shows cached states when the refresh exceeds its budget', () async {
        await home.loadDevices();
        final pendingIps = Completer<List<String>>();
        when(storage.getDeviceIps()).thenAnswer((_) => pendingIps.future);

        await shell.rightClickTray();

        expect(_describe(shell.menus.single), contains('Bureau'));
        pendingIps.complete([]);
        await home.refresh();
      });

      test('disables "Tout éteindre" when every plug is off', () async {
        when(
          storage.getDeviceIps(),
        ).thenAnswer((_) async => [_bureau, _chambre]);

        await shell.rightClickTray();

        expect(
          _describe(shell.menus.single),
          contains('Tout éteindre (grisé)'),
        );
      });

      test('offers only window actions without configured plugs', () async {
        when(storage.getDeviceIps()).thenAnswer((_) async => []);

        await shell.rightClickTray();

        expect(_describe(shell.menus.single), [
          'Tapo · aucune prise (grisé)',
          '---',
          'Ouvrir Tapo',
          'Lancer au démarrage',
          'Quitter',
        ]);
      });

      test('reflects "Lancer au démarrage" changed outside the app', () async {
        // e.g. disabled from Task Manager's Startup apps while running.
        shell.launchAtStartup = true;

        await shell.rightClickTray();

        expect(
          _describe(shell.menus.single),
          contains('✓ Lancer au démarrage'),
        );
      });
    });

    group('actions', () {
      setUp(() async {
        await shell.rightClickTray();
      });

      test('a plug item toggles that plug', () async {
        when(tapo.toggleDevice(_bureau)).thenAnswer(
          (_) async =>
              TestFixtures.onlineDevice(ip: _bureau, nickname: 'Bureau'),
        );

        await shell.select('Bureau');

        verify(tapo.toggleDevice(_bureau)).called(1);
        expect(home.devices[1].deviceOn, isTrue);
        expect(shell.notifications, isEmpty);
      });

      test('warns when the plug cannot be reached', () async {
        when(tapo.toggleDevice(_bureau)).thenAnswer(
          (_) async => TestFixtures.onlineDevice(
            ip: _bureau,
            nickname: 'Bureau',
            deviceOn: false,
          ).copyWith(isOnline: false),
        );

        await shell.select('Bureau');

        expect(shell.notifications.single.message, 'Bureau est injoignable');
      });

      test('does not warn when a toggle is skipped by the cooldown', () async {
        when(tapo.toggleDevice(_bureau)).thenThrow(Exception('timeout'));
        await shell.select('Bureau');

        // Same plug again within the double-click cooldown: nothing is sent.
        await shell.select('Bureau');

        verify(tapo.toggleDevice(_bureau)).called(1);
        expect(shell.notifications, hasLength(1));
      });

      test('"Tout éteindre" turns the lit plugs off', () async {
        when(tapo.setDevicePower(_salon, on: false)).thenAnswer(
          (_) async =>
              TestFixtures.onlineDevice(nickname: 'Salon', deviceOn: false),
        );

        await shell.select('Tout éteindre');

        verify(tapo.setDevicePower(_salon, on: false)).called(1);
      });

      test('"Ouvrir Tapo" shows the window', () async {
        await shell.select('Ouvrir Tapo');

        expect(shell.showWindowCalls, 1);
      });

      test('"Quitter" quits the app', () async {
        await shell.select('Quitter');

        expect(shell.quitCalls, 1);
      });

      test('"Lancer au démarrage" flips the setting', () async {
        await shell.select('Lancer au démarrage');

        expect(shell.launchAtStartup, isTrue);
        expect(launchAtStartup.isEnabled, isTrue);
      });
    });

    group('tooltip', () {
      test('summarises how many plugs are on', () async {
        await home.loadDevices();

        expect(shell.tooltips.last, 'Tapo · 1/3 allumées');
      });

      test('is only resent when the summary changes', () async {
        await home.loadDevices();
        final sent = shell.tooltips.length;

        await home.loadDevices();

        expect(shell.tooltips, hasLength(sent));
      });
    });
  });
}
