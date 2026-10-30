import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/providers/auth_provider.dart';
import 'package:tapo/providers/services.dart';

import '../helpers/fake_plugs.dart';
import '../helpers/providers.dart';
import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

void main() {
  late MockSecureStorageService storage;
  late MockWidgetDataService widgetData;
  late ProviderContainer container;

  setUp(() {
    storage = stubbedStorage();
    widgetData = stubbedWidgetData();
    container = ProviderContainer.test(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        widgetDataProvider.overrideWithValue(widgetData),
      ],
    );
  });

  group('authProvider', () {
    test('starts signed in with the stored account', () async {
      stubSignedIn(storage);

      expect(await container.read(authProvider.future), (
        email: TestFixtures.testEmail,
        password: TestFixtures.testPassword,
      ));
    });

    for (final (email, password) in [
      (null, null),
      (TestFixtures.testEmail, null),
      (null, TestFixtures.testPassword),
    ]) {
      test('starts signed out with email $email, password $password', () async {
        when(
          storage.getCredentials(),
        ).thenAnswer((_) async => (email: email, password: password));

        expect(await container.read(authProvider.future), isNull);
      });
    }

    test('starts signed out when the storage cannot be read', () async {
      when(storage.getCredentials()).thenThrow(Exception('keystore'));

      expect(await container.read(authProvider.future), isNull);
    });

    test('login stores the account and signs in', () async {
      await container.read(authProvider.future);

      await container
          .read(authProvider.notifier)
          .login(TestFixtures.testEmail, TestFixtures.testPassword);

      verify(
        storage.saveCredentials(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        ),
      ).called(1);
      expect(container.read(authProvider).value?.email, TestFixtures.testEmail);
    });

    test('logout forgets the account, its plugs and the widgets', () async {
      stubSignedIn(storage);
      await container.read(authProvider.future);

      await container.read(authProvider.notifier).logout();

      verify(storage.clearCredentials()).called(1);
      verify(storage.clearDeviceIps()).called(1);
      verify(widgetData.clearWidgetData()).called(1);
      expect(container.read(authProvider).value, isNull);
    });
  });

  group('tapoServiceProvider', () {
    test('is null while signed out', () async {
      await container.read(authProvider.future);

      expect(container.read(tapoServiceProvider), isNull);
    });

    test('signing out closes the plug sessions', () {
      stubSignedIn(storage);
      // TPAP keeps a connection per session, unlike KLAP.
      final plug = FakeTpapPlugWithLogin();
      var sessionOpen = false;

      runAgainstPlugs(() async {
        await container.read(authProvider.future);
        final service = container.read(tapoServiceProvider)!;
        await service.getDeviceState(TestFixtures.testDeviceIp);
        sessionOpen = !plug.allClientsClosed;

        await container.read(authProvider.notifier).logout();

        expect(container.read(tapoServiceProvider), isNull);
      }, tpap: plug);

      expect(sessionOpen, isTrue);
      expect(plug.allClientsClosed, isTrue);
    });
  });
}
