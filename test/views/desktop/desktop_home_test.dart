import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/providers/home_provider.dart';
import 'package:tapo/providers/services.dart';
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
  late FakeHomeNotifier home;
  late FakeDesktopShell shell;

  setUp(() {
    home = FakeHomeNotifier();
    shell = FakeDesktopShell();
  });

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
      ProviderScope(
        overrides: [
          homeProvider.overrideWith(() => home),
          desktopShellProvider.overrideWithValue(shell),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: const HomeScreen(),
        ),
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
      home = FakeHomeNotifier.withDevices([_lamp, _desk, _bedroom]);
      await pumpHome(tester);

      expect(find.byType(PlugTile), findsNWidgets(3));
      expect(find.byType(PlugCard), findsNothing);
    });

    testWidgets('keeps the mobile list on a narrow window', (tester) async {
      home = FakeHomeNotifier.withDevices([_lamp, _desk, _bedroom]);
      await pumpHome(tester, size: const Size(400, 800));

      expect(find.byType(PlugCard), findsNWidgets(3));
      expect(find.byType(PlugTile), findsNothing);
    });

    testWidgets('error state keeps the sidebar', (tester) async {
      home = FakeHomeNotifier(
        const HomeState(errorMessage: 'Connection failed'),
      );
      await pumpHome(tester);

      expect(find.text('Connexion impossible'), findsOneWidget);
      expect(find.text('Ma maison'), findsOneWidget);
      expect(find.text('Tout éteindre'), findsOneWidget);
    });

    group('sidebar', () {
      testWidgets('Tout éteindre turns every plug off', (tester) async {
        home = FakeHomeNotifier.withDevices([_lamp, _desk]);
        await pumpHome(tester);

        await tester.tap(find.text('Tout éteindre'));
        await tester.pump();

        expect(home.turnOffAllCallCount, 1);
      });

      testWidgets('Tout éteindre does nothing when no plug is on', (
        tester,
      ) async {
        home = FakeHomeNotifier.withDevices([_desk, _bedroom]);
        await pumpHome(tester);

        await tester.tap(find.text('Tout éteindre'));
        await tester.pump();

        expect(home.turnOffAllCallCount, 0);
      });

      testWidgets('Actualiser refreshes silently with a spinner', (
        tester,
      ) async {
        home = FakeHomeNotifier.withDevices([_lamp])
          ..refreshCompleter = Completer<void>();
        await pumpHome(tester);

        await tester.tap(find.text('Actualiser'));
        await tester.pump();

        expect(home.refreshCallCount, 1);
        expect(home.lastRefreshSilent, isTrue);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        home.refreshCompleter!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('F5 refreshes silently', (tester) async {
        home = FakeHomeNotifier.withDevices([_lamp]);
        await pumpHome(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.f5);
        await tester.pumpAndSettle();

        expect(home.refreshCallCount, 1);
        expect(home.lastRefreshSilent, isTrue);
      });

      testWidgets('hides launch at startup outside Windows', (tester) async {
        home = FakeHomeNotifier.withDevices([_lamp]);
        await pumpHome(tester);

        expect(find.text('Lancer au démarrage'), findsNothing);
      });

      testWidgets('launch at startup switch updates the setting on Windows', (
        tester,
      ) async {
        home = FakeHomeNotifier.withDevices([_lamp]);
        await pumpHome(tester);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(shell.launchAtStartup, isTrue);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    });

    group('plug tile', () {
      testWidgets('power button toggles the plug', (tester) async {
        home = FakeHomeNotifier.withDevices([_desk]);
        await pumpHome(tester);

        await tester.tap(find.byKey(const ValueKey('power-192.168.1.11')));
        await tester.pump();

        expect(home.lastToggledIp, '192.168.1.11');
      });

      testWidgets('countdown chip schedules the power-off', (tester) async {
        home = FakeHomeNotifier.withDevices([_lamp]);
        await pumpHome(tester);

        await tester.tap(find.byKey(const ValueKey('countdown-192.168.1.10')));
        await tester.pump();

        expect(home.lastScheduledIp, '192.168.1.10');
      });

      testWidgets('right click opens the plug menu', (tester) async {
        home = FakeHomeNotifier.withDevices([_lamp]);
        await pumpHome(tester);

        await openTileMenu(tester, 'Lampe Salon');

        expect(find.text("Modifier l'IP"), findsOneWidget);
        expect(find.text('Supprimer'), findsOneWidget);
      });

      testWidgets('options button opens the plug menu', (tester) async {
        home = FakeHomeNotifier.withDevices([_lamp]);
        await pumpHome(tester);

        await tester.tap(find.byTooltip('Options'));
        await tester.pumpAndSettle();

        expect(find.text("Modifier l'IP"), findsOneWidget);
      });

      testWidgets('Supprimer removes the plug after confirmation', (
        tester,
      ) async {
        home = FakeHomeNotifier.withDevices([_lamp, _desk]);
        await pumpHome(tester);

        await openTileMenu(tester, 'Bureau');
        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();
        expect(home.lastRemovedIp, isNull);

        await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
        await tester.pumpAndSettle();

        expect(home.lastRemovedIp, '192.168.1.11');
      });

      testWidgets("Modifier l'IP saves the new address", (tester) async {
        home = FakeHomeNotifier.withDevices([_lamp]);
        await pumpHome(tester);

        await openTileMenu(tester, 'Lampe Salon');
        await tester.tap(find.text("Modifier l'IP"));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '192.168.1.50');
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();

        expect(home.lastIpUpdate, (
          oldIp: '192.168.1.10',
          newIp: '192.168.1.50',
        ));
      });
    });

    testWidgets('window focus only refreshes stale data on desktop', (
      tester,
    ) async {
      home = FakeHomeNotifier.withDevices([_lamp]);
      await pumpHome(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(home.refreshIfStaleCallCount, 1);
      expect(home.refreshCallCount, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
