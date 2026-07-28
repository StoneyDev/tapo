import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/views/widgets/plug_card.dart';

import '../../helpers/test_utils.dart';

void main() {
  group('PlugCard', () {
    late bool toggleCalled;
    late bool removeCalled;
    late String? editedIp;

    setUp(() {
      toggleCalled = false;
      removeCalled = false;
      editedIp = null;
    });

    Widget buildTestWidget(TapoDevice device, {bool isToggling = false}) {
      return MaterialApp(
        home: Scaffold(
          body: PlugCard(
            device: device,
            onToggle: () => toggleCalled = true,
            onRemove: () => removeCalled = true,
            onEditIp: (newIp) => editedIp = newIp,
            isToggling: isToggling,
          ),
        ),
      );
    }

    group('icon rendering', () {
      testWidgets('online + on state renders green power icon', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        final iconFinder = find.byIcon(Icons.power);
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.color, Colors.green);
      });

      testWidgets('online + off state renders grey power_off icon', (
        tester,
      ) async {
        final device = TestFixtures.onlineDevice(deviceOn: false);
        await tester.pumpWidget(buildTestWidget(device));

        final iconFinder = find.byIcon(Icons.power_off);
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.color, Colors.grey);
      });

      testWidgets('offline state renders error-colored icon', (tester) async {
        final device = TestFixtures.offlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        final iconFinder = find.byIcon(Icons.power_off);
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        // Error color comes from theme colorScheme
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
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.text('P110'), findsOneWidget);
      });

      testWidgets('displays IP address', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.text(TestFixtures.testDeviceIp), findsOneWidget);
      });

      testWidgets('displays Unknown Device for empty nickname', (tester) async {
        const device = TapoDevice(
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
        const device = TapoDevice(
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
      testWidgets('shows spinner while toggling', (
        tester,
      ) async {
        final device = TestFixtures.onlineDevice();

        await tester.pumpWidget(buildTestWidget(device, isToggling: true));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('power interaction', () {
      testWidgets('power tap calls onToggle for online device', (
        tester,
      ) async {
        final device = TestFixtures.onlineDevice(deviceOn: false);
        await tester.pumpWidget(buildTestWidget(device));

        await tester.tap(
          find.byKey(const ValueKey('power-${TestFixtures.testDeviceIp}')),
        );
        await tester.pump();

        expect(toggleCalled, isTrue);
      });

      testWidgets('power button is disabled for offline device', (
        tester,
      ) async {
        final device = TestFixtures.offlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.tap(
          find.byKey(const ValueKey('power-${TestFixtures.testDeviceIp}')),
        );
        await tester.pump();

        expect(toggleCalled, isFalse);
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

    group('long press edit IP dialog', () {
      testWidgets('long press opens dialog with current IP', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.longPress(find.byType(Card));
        await tester.pumpAndSettle();

        expect(find.text("Modifier l'adresse IP"), findsOneWidget);
        final textField = tester.widget<TextFormField>(
          find.byType(TextFormField),
        );
        expect(textField.controller?.text, TestFixtures.testDeviceIp);
      });

      testWidgets('save with valid changed IP calls onEditIp', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.longPress(find.byType(Card));
        await tester.pumpAndSettle();

        // Clear and enter new IP
        await tester.enterText(find.byType(TextFormField), '10.0.0.1');
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();

        expect(editedIp, '10.0.0.1');
      });

      testWidgets('cancel does not call onEditIp', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.longPress(find.byType(Card));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), '10.0.0.1');
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();

        expect(editedIp, isNull);
      });

      testWidgets('save with same IP does not call onEditIp', (tester) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.longPress(find.byType(Card));
        await tester.pumpAndSettle();

        // Don't change the IP, just tap save
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();

        expect(editedIp, isNull);
      });

      testWidgets('save with invalid IP shows validation error', (
        tester,
      ) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.longPress(find.byType(Card));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'not-an-ip');
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();

        expect(find.text('Format IP invalide'), findsOneWidget);
        expect(editedIp, isNull);
      });

      testWidgets('save with empty IP shows validation error', (
        tester,
      ) async {
        final device = TestFixtures.onlineDevice();
        await tester.pumpWidget(buildTestWidget(device));

        await tester.longPress(find.byType(Card));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), '');
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();

        expect(find.text('Adresse IP requise'), findsOneWidget);
        expect(editedIp, isNull);
      });
    });

    group('card structure', () {
      testWidgets('renders Card with device IP as key', (tester) async {
        final device = TestFixtures.onlineDevice(ip: '10.0.0.5');
        await tester.pumpWidget(buildTestWidget(device));

        expect(find.byType(Card), findsOneWidget);
        final dismissible = tester.widget<Dismissible>(
          find.byType(Dismissible),
        );
        expect(dismissible.key, const Key('10.0.0.5'));
      });
    });
  });
}
