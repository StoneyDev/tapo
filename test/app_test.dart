import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/main.dart';

import 'helpers/providers.dart';
import 'helpers/test_utils.dart';
import 'helpers/test_utils.mocks.dart';

void main() {
  late MockSecureStorageService storage;

  setUp(() => storage = stubbedStorage());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(storage: storage, tapo: MockTapoService()),
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MyApp', () {
    testWidgets('opens the configuration without a stored account', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Configuration'), findsOneWidget);
    });

    testWidgets('opens home with a stored account', (tester) async {
      stubSignedIn(storage);

      await pumpApp(tester);

      expect(find.text('Ma maison'), findsOneWidget);
    });

    testWidgets('saving the configuration opens home', (tester) async {
      await pumpApp(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Adresse e-mail'),
        TestFixtures.testEmail,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Mot de passe'),
        TestFixtures.testPassword,
      );
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Ma maison'), findsOneWidget);
    });

    testWidgets('logging out returns to the configuration', (tester) async {
      stubSignedIn(storage);
      await pumpApp(tester);

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      verify(storage.clearCredentials()).called(1);
      expect(find.text('Configuration'), findsOneWidget);
    });
  });
}
