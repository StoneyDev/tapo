import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/providers/auth_provider.dart';
import 'package:tapo/providers/services.dart';
import 'package:tapo/views/config_screen.dart';

import '../helpers/providers.dart';
import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

// Different from the IP field hint, 192.168.1.100.
const _ip1 = '10.0.0.1';
const _ip2 = '10.0.0.2';

void main() {
  late MockSecureStorageService storage;
  late ProviderContainer container;

  setUp(() => storage = stubbedStorage());

  Future<void> pumpConfig(WidgetTester tester, {bool settle = true}) async {
    container = ProviderContainer.test(
      overrides: [secureStorageProvider.overrideWithValue(storage)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConfigScreen()),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> addIp(WidgetTester tester, String ip) async {
    await tester.enterText(find.widgetWithText(TextField, 'Adresse IP'), ip);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, String password) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Adresse e-mail'),
      TestFixtures.testEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Mot de passe'),
      password,
    );
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
  }

  group('ConfigScreen', () {
    testWidgets('renders the form, prefilled with the stored email', (
      tester,
    ) async {
      when(storage.getCredentials()).thenAnswer(
        (_) async => (email: TestFixtures.testEmail, password: null),
      );
      await pumpConfig(tester);

      expect(find.text('Configuration'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mot de passe'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Adresse IP'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Enregistrer'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, TestFixtures.testEmail),
        findsOneWidget,
      );
    });

    testWidgets('shows a spinner until the configuration is loaded', (
      tester,
    ) async {
      final ips = Completer<List<String>>();
      when(storage.getDeviceIps()).thenAnswer((_) => ips.future);
      await pumpConfig(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Adresse e-mail'), findsNothing);

      ips.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Adresse e-mail'), findsOneWidget);
    });

    group('plugs', () {
      testWidgets('an added IP is listed and the field cleared', (
        tester,
      ) async {
        await pumpConfig(tester);

        await addIp(tester, _ip1);

        expect(find.text(_ip1), findsOneWidget);
        final field = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Adresse IP'),
        );
        expect(field.controller?.text, '');
      });

      testWidgets('an empty IP field adds nothing', (tester) async {
        await pumpConfig(tester);

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete), findsNothing);
        expect(find.text('IP address cannot be empty'), findsNothing);
      });

      testWidgets('shows why an IP is rejected', (tester) async {
        await pumpConfig(tester);

        await addIp(tester, 'not-an-ip');

        expect(find.text('Invalid IP address format'), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsNothing);
      });

      testWidgets('delete removes the stored IP from the list', (tester) async {
        when(storage.getDeviceIps()).thenAnswer((_) async => [_ip1, _ip2]);
        await pumpConfig(tester);
        expect(find.byIcon(Icons.delete), findsNWidgets(2));

        await tester.ensureVisible(find.byIcon(Icons.delete).first);
        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        expect(find.text(_ip1), findsNothing);
        expect(find.text(_ip2), findsOneWidget);
      });
    });

    group('save', () {
      testWidgets('signs in with the entered account and plugs', (
        tester,
      ) async {
        await pumpConfig(tester);
        await addIp(tester, _ip1);

        await save(tester, TestFixtures.testPassword);

        verify(storage.saveDeviceIps([_ip1])).called(1);
        expect(container.read(authProvider).value, (
          email: TestFixtures.testEmail,
          password: TestFixtures.testPassword,
        ));
      });

      testWidgets('stays on the form with the error when invalid', (
        tester,
      ) async {
        await pumpConfig(tester);

        await save(tester, 'short');

        expect(
          find.text('Password must be at least 8 characters'),
          findsOneWidget,
        );
        expect(container.read(authProvider).value, isNull);
      });
    });
  });
}
