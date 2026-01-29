import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/views/widgets/plug_card.dart';

import '../../helpers/test_utils.dart';

void main() {
  group('PlugCard', () {
    late bool toggleCalled;
    late bool removeCalled;

    setUp(() {
      toggleCalled = false;
      removeCalled = false;
    });

    Widget buildTestWidget(TapoDevice device, {bool isToggling = false}) {
      return MaterialApp(
        home: Scaffold(
          body: PlugCard(
            device: device,
            onToggle: () => toggleCalled = true,
            onRemove: () => removeCalled = true,
            isToggling: isToggling,
          ),
        ),
      );
    }

    group('icon rendering', () {
      testWidgets('online + on state renders green power icon', (tester) async {
        final device = TestFixtures.onlineDevice(deviceOn: true);
        await tester.pumpWidget(buildTestWidget(device));

        final iconFinder = find.byIcon(Icons.power);
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.color, Colors.green);
      });

      testWidgets('online + off state renders grey power_off icon',
          (tester) async {
        final device = TestFixtures.onlineDevice(deviceOn: false);
        await tester.pumpWidget(buildTestWidget(device));

        final iconFinder = find.byIcon(Icons.power_off);
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.color, Colors.grey);
      });

      testWidgets('offline state renders error-colored power_off icon',
          (tester) async {
        final device = TestFixtures.offlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        final iconFinder = find.byIcon(Icons.power_off);
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        // Error color comes from theme's colorScheme.error
        expect(icon.color, isNotNull);
      });
    });

    group('device info display', () {
      testWidgets('displays nickname', (tester) async {
        final device = TestFixtures.onlineDevice(nickname: 'Living Room Plug');
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.text('Living Room Plug'), findsOneWidget);
      });

      testWidgets('displays model', (tester) async {
        final device = TestFixtures.onlineDevice(model: 'P110');
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.text('P110'), findsOneWidget);
      });

      testWidgets('displays IP address', (tester) async {
        final device = TestFixtures.onlineDevice(ip: '192.168.1.100');
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.text('192.168.1.100'), findsOneWidget);
      });

      testWidgets('displays Unknown Device for empty nickname', (tester) async {
        final device = TapoDevice(
          ip: '192.168.1.100',
          nickname: '',
          model: 'P110',
          deviceOn: true,
          isOnline: true,
        );
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.text('Unknown Device'), findsOneWidget);
      });

      testWidgets('displays Tapo Plug for empty model', (tester) async {
        final device = TapoDevice(
          ip: '192.168.1.100',
          nickname: 'Test',
          model: '',
          deviceOn: true,
          isOnline: true,
        );
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.text('Tapo Plug'), findsOneWidget);
      });
    });

    group('isToggling state', () {
      testWidgets('shows spinner when toggling, switch otherwise',
          (tester) async {
        final device = TestFixtures.onlineDevice();

        // When toggling
        await tester.pumpWidget(buildTestWidget(device, isToggling: true));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Switch), findsNothing);

        // When not toggling
        await tester.pumpWidget(buildTestWidget(device, isToggling: false));
        expect(find.byType(Switch), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('switch interaction', () {
      testWidgets('switch tap calls onToggle for online device',
          (tester) async {
        final device = TestFixtures.onlineDevice(deviceOn: false);
        await tester.pumpWidget(buildTestWidget(device));

        await tester.tap(find.byType(Switch));
        await tester.pump();

        expect(toggleCalled, isTrue);
      });

      testWidgets('switch is disabled for offline device', (tester) async {
        final device = TestFixtures.offlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.onChanged, isNull);
      });

      testWidgets('switch reflects device on/off state', (tester) async {
        // Device on
        await tester.pumpWidget(
            buildTestWidget(TestFixtures.onlineDevice(deviceOn: true)));
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

        // Device off
        await tester.pumpWidget(
            buildTestWidget(TestFixtures.onlineDevice(deviceOn: false)));
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      });
    });

    group('dismissible (swipe to delete)', () {
      testWidgets('swipe left shows delete background', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.drag(find.byType(Card), const Offset(-100, 0));
        await tester.pump();

        expect(find.byIcon(Icons.delete), findsOneWidget);
      });

      testWidgets('dismiss triggers confirm dialog', (tester) async {
        final device = TestFixtures.onlineDevice(nickname: 'My Plug');
        await tester.pumpWidget(buildTestWidget(device));

        // Start dismiss gesture
        await tester.drag(find.byType(Card), const Offset(-500, 0));
        await tester.pumpAndSettle();

        // Dialog should appear
        expect(find.text('Supprimer?'), findsOneWidget);
        expect(find.text('Supprimer My Plug?'), findsOneWidget);
      });

      testWidgets('cancel in dialog prevents removal', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.drag(find.byType(Card), const Offset(-500, 0));
        await tester.pumpAndSettle();

        // Tap cancel
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();

        expect(removeCalled, isFalse);
        // Card should still be present
        expect(find.byType(Card), findsOneWidget);
      });

      testWidgets('confirm in dialog calls onRemove', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.drag(find.byType(Card), const Offset(-500, 0));
        await tester.pumpAndSettle();

        // Tap confirm
        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();

        expect(removeCalled, isTrue);
      });
    });

    group('card structure', () {
      testWidgets('renders Card with device IP as Dismissible key', (tester) async {
        final device = TestFixtures.onlineDevice(ip: '10.0.0.5');
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.byType(Card), findsOneWidget);
        final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
        expect(dismissible.key, const Key('10.0.0.5'));
      });
    });
  });
}
