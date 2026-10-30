import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/providers/home_provider.dart';
import 'package:jolt/views/home_screen.dart';
import 'package:jolt/views/widgets/plug_card.dart';

import '../helpers/test_utils.dart';
import 'home_test_doubles.dart';

void main() {
  late FakeHomeNotifier home;

  setUp(() => home = FakeHomeNotifier());

  /// Phone-sized app: these tests cover the mobile layout.
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeProvider.overrideWith(() => home)],
        child: MaterialApp(
          builder: (context, child) =>
              Center(child: SizedBox(width: 400, child: child)),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  group('HomeScreen', () {
    testWidgets('shows spinner when loading, hides otherwise', (tester) async {
      home = FakeHomeNotifier(const HomeState(isLoading: true));
      await pumpHome(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      home.state = const HomeState();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    group('device list', () {
      testWidgets('renders PlugCards for each device', (tester) async {
        home = FakeHomeNotifier.withDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1', nickname: 'Device 1'),
          TestFixtures.onlineDevice(ip: '10.0.0.2', nickname: 'Device 2'),
        ]);
        await pumpHome(tester);

        expect(find.byType(PlugCard), findsNWidgets(2));
        expect(find.text('Device 1'), findsOneWidget);
        expect(find.text('Device 2'), findsOneWidget);
      });

      testWidgets('displays empty state message when no devices', (
        tester,
      ) async {
        await pumpHome(tester);

        expect(find.text('No devices configured'), findsOneWidget);
      });

      testWidgets('retry button of the error message refreshes', (
        tester,
      ) async {
        home = FakeHomeNotifier(
          const HomeState(errorMessage: 'Connection failed'),
        );
        await pumpHome(tester);
        expect(find.text('Connection failed'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(home.refreshCallCount, 1);
      });

      testWidgets('pull down triggers refresh', (tester) async {
        home = FakeHomeNotifier.withDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1'),
        ]);
        await pumpHome(tester);

        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pumpAndSettle();

        expect(home.refreshCallCount, 1);
      });
    });

    group('device interactions', () {
      testWidgets('device toggle triggers toggleDevice', (tester) async {
        home = FakeHomeNotifier.withDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1', deviceOn: false),
        ]);
        await pumpHome(tester);

        await tester.tap(find.byKey(const ValueKey('power-10.0.0.1')));
        await tester.pump();

        expect(home.lastToggledIp, '10.0.0.1');
      });

      testWidgets('a toggling plug shows a spinner', (tester) async {
        home = FakeHomeNotifier(
          HomeState(
            devices: [TestFixtures.onlineDevice(ip: '10.0.0.1')],
            toggling: {'10.0.0.1'},
          ),
        );
        await pumpHome(tester);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byKey(const ValueKey('power-10.0.0.1')), findsOneWidget);
      });

      testWidgets('follows the countdown of a scheduled plug', (tester) async {
        final device = TestFixtures.onlineDevice(ip: '10.0.0.1');
        home = FakeHomeNotifier(
          HomeState(
            devices: [device],
            powerOffRemaining: {'10.0.0.1': const Duration(seconds: 42)},
          ),
        );
        await pumpHome(tester);
        expect(find.text('Arrêt dans 0:42'), findsOneWidget);

        home.state = HomeState(
          devices: [device],
          powerOffRemaining: {'10.0.0.1': const Duration(seconds: 41)},
        );
        await tester.pump();

        expect(find.text('Arrêt dans 0:41'), findsOneWidget);
      });
    });

    testWidgets('app resume triggers refresh', (tester) async {
      await pumpHome(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(home.refreshCallCount, 1);
    });
  });
}
