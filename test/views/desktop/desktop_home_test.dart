import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/viewmodels/launch_at_startup_viewmodel.dart';
import 'package:tapo/views/desktop/plug_tile.dart';
import 'package:tapo/views/home_screen.dart';
import 'package:tapo/views/widgets/plug_card.dart';

import '../../helpers/fake_desktop_shell.dart';
import '../home_test_doubles.dart';

const _lamp = TapoDevice(
  ip: '192.168.1.10',
  nickname: 'Lampe Salon',
  model: 'P110',
  deviceOn: true,
  isOnline: true,
);
const _desk = TapoDevice(
  ip: '192.168.1.11',
  nickname: 'Bureau',
  model: 'P100',
  deviceOn: false,
  isOnline: true,
);
const _bedroom = TapoDevice(
  ip: '192.168.1.12',
  nickname: 'Chambre',
  model: 'P110',
  deviceOn: false,
  isOnline: false,
);

void main() {
  late MockHomeViewModel viewModel;
  late FakeDesktopShell shell;
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
    viewModel = MockHomeViewModel();
    shell = FakeDesktopShell();
    getIt
      ..registerSingleton<HomeViewModel>(viewModel)
      ..registerSingleton<LaunchAtStartupViewModel>(
        LaunchAtStartupViewModel(shell: shell),
      )
      ..registerSingleton<SecureStorageService>(MockSecureStorageService())
      ..registerSingleton<TapoService>(MockTapoService())
      ..registerSingleton<WidgetDataService>(MockWidgetDataService());
  });

  tearDown(getIt.reset);

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(1000, 660),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Roboto: the Windows default font (Segoe UI) is not available in tests.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTileMenu(WidgetTester tester, String nickname) async {
    await tester.tap(
      find.text(nickname),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  group('Desktop home layout', () {
    testWidgets('shows a tile per device on a wide window', (tester) async {
      viewModel.setDevices([_lamp, _desk, _bedroom]);
      await pumpHome(tester);

      expect(find.byType(PlugTile), findsNWidgets(3));
      expect(find.byType(PlugCard), findsNothing);
    });

    testWidgets('keeps the mobile list on a narrow window', (tester) async {
      viewModel.setDevices([_lamp, _desk, _bedroom]);
      await pumpHome(tester, size: const Size(400, 800));

      expect(find.byType(PlugCard), findsNWidgets(3));
      expect(find.byType(PlugTile), findsNothing);
    });

    testWidgets('error state keeps the sidebar', (tester) async {
      viewModel.setErrorMessage('Connection failed');
      await pumpHome(tester);

      expect(find.text('Connexion impossible'), findsOneWidget);
      expect(find.text('Ma maison'), findsOneWidget);
      expect(find.text('Tout éteindre'), findsOneWidget);
    });

    group('sidebar', () {
      testWidgets('Tout éteindre turns every plug off', (tester) async {
        viewModel.setDevices([_lamp, _desk]);
        await pumpHome(tester);

        await tester.tap(find.text('Tout éteindre'));
        await tester.pump();

        expect(viewModel.turnOffAllCallCount, 1);
      });

      testWidgets('Tout éteindre does nothing when no plug is on', (
        tester,
      ) async {
        viewModel.setDevices([_desk, _bedroom]);
        await pumpHome(tester);

        await tester.tap(find.text('Tout éteindre'));
        await tester.pump();

        expect(viewModel.turnOffAllCallCount, 0);
      });

      testWidgets('Actualiser refreshes silently with a spinner', (
        tester,
      ) async {
        viewModel
          ..setDevices([_lamp])
          ..refreshCompleter = Completer<void>();
        await pumpHome(tester);

        await tester.tap(find.text('Actualiser'));
        await tester.pump();

        expect(viewModel.refreshCallCount, 1);
        expect(viewModel.lastRefreshSilent, isTrue);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        viewModel.refreshCompleter!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('F5 refreshes silently', (tester) async {
        viewModel.setDevices([_lamp]);
        await pumpHome(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.f5);
        await tester.pumpAndSettle();

        expect(viewModel.refreshCallCount, 1);
        expect(viewModel.lastRefreshSilent, isTrue);
      });

      testWidgets('hides launch at startup outside Windows', (tester) async {
        viewModel.setDevices([_lamp]);
        await pumpHome(tester);

        expect(find.text('Lancer au démarrage'), findsNothing);
      });

      testWidgets('launch at startup switch updates the setting on Windows', (
        tester,
      ) async {
        viewModel.setDevices([_lamp]);
        await pumpHome(tester);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(shell.launchAtStartup, isTrue);
        expect(getIt<LaunchAtStartupViewModel>().isEnabled, isTrue);
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    });

    group('plug tile', () {
      testWidgets('power button toggles the plug', (tester) async {
        viewModel.setDevices([_desk]);
        await pumpHome(tester);

        await tester.tap(find.byKey(const ValueKey('power-192.168.1.11')));
        await tester.pump();

        expect(viewModel.lastToggledIp, '192.168.1.11');
      });

      testWidgets('countdown chip schedules the power-off', (tester) async {
        viewModel.setDevices([_lamp]);
        await pumpHome(tester);

        await tester.tap(find.byKey(const ValueKey('countdown-192.168.1.10')));
        await tester.pump();

        expect(viewModel.schedulePowerOffCallCount, 1);
      });

      testWidgets('right click opens the plug menu', (tester) async {
        viewModel.setDevices([_lamp]);
        await pumpHome(tester);

        await openTileMenu(tester, 'Lampe Salon');

        expect(find.text("Modifier l'IP"), findsOneWidget);
        expect(find.text('Supprimer'), findsOneWidget);
      });

      testWidgets('options button opens the plug menu', (tester) async {
        viewModel.setDevices([_lamp]);
        await pumpHome(tester);

        await tester.tap(find.byTooltip('Options'));
        await tester.pumpAndSettle();

        expect(find.text("Modifier l'IP"), findsOneWidget);
      });

      testWidgets('Supprimer removes the plug after confirmation', (
        tester,
      ) async {
        viewModel.setDevices([_lamp, _desk]);
        await pumpHome(tester);

        await openTileMenu(tester, 'Bureau');
        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();
        expect(viewModel.removeDeviceCallCount, 0);

        await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
        await tester.pumpAndSettle();

        expect(viewModel.lastRemovedIp, '192.168.1.11');
      });

      testWidgets("Modifier l'IP saves the new address", (tester) async {
        viewModel.setDevices([_lamp]);
        await pumpHome(tester);

        await openTileMenu(tester, 'Lampe Salon');
        await tester.tap(find.text("Modifier l'IP"));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '192.168.1.50');
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();

        expect(viewModel.lastOldIp, '192.168.1.10');
        expect(viewModel.lastNewIp, '192.168.1.50');
      });
    });

    testWidgets('window focus only refreshes stale data on desktop', (
      tester,
    ) async {
      viewModel.setDevices([_lamp]);
      await pumpHome(tester);
      viewModel.refreshCallCount = 0;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.refreshIfStaleCallCount, 1);
      expect(viewModel.refreshCallCount, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
