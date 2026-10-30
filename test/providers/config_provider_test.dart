import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/providers/auth_provider.dart';
import 'package:jolt/providers/config_provider.dart';
import 'package:jolt/providers/services.dart';
import 'package:mockito/mockito.dart';

import '../helpers/providers.dart';
import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

const String _ip = TestFixtures.testDeviceIp;
const String _ip2 = TestFixtures.testDeviceIp2;

void main() {
  late MockSecureStorageService storage;
  late ProviderContainer container;

  setUp(() {
    storage = stubbedStorage();
    container = ProviderContainer.test(
      overrides: [secureStorageProvider.overrideWithValue(storage)],
    );
  });

  Future<ConfigNotifier> loaded() async {
    // Keeps the auto-dispose form alive between reads.
    container.listen(configProvider, (_, _) {});
    await container.read(configProvider.future);
    return container.read<ConfigNotifier>(configProvider.notifier);
  }

  ConfigState state() => container.read(configProvider).requireValue;

  group('ConfigNotifier', () {
    group('load', () {
      test('prefills the stored email and plugs', () async {
        stubSignedIn(storage);
        when(storage.getDeviceIps()).thenAnswer((_) async => [_ip]);

        await loaded();

        expect(
          state(),
          const ConfigState(email: TestFixtures.testEmail, deviceIps: [_ip]),
        );
      });

      test('starts empty without a stored account', () async {
        await loaded();

        expect(state(), const ConfigState());
      });

      test('reports a storage failure', () async {
        when(storage.getCredentials()).thenThrow(Exception('Storage error'));

        await loaded();

        expect(state().errorMessage, 'Failed to load configuration');
      });
    });

    group('saveConfig', () {
      for (final (email, password, error) in [
        ('', TestFixtures.testPassword, 'Email and password required'),
        (TestFixtures.testEmail, '', 'Email and password required'),
        ('not-an-email', TestFixtures.testPassword, 'Invalid email format'),
        (
          TestFixtures.testEmail,
          'short',
          'Password must be at least 8 characters',
        ),
      ]) {
        test('rejects "$email" / "$password": $error', () async {
          final config = await loaded();

          await config.saveConfig(email, password);

          expect(state().errorMessage, error);
          verifyNever(storage.saveCredentials(any, any));
          expect(container.read(authProvider).value, isNull);
        });
      }

      for (final email in [
        'user@example.com',
        'user.name@example.com',
        'user+tag@example.co.uk',
      ]) {
        test('accepts $email', () async {
          final config = await loaded();

          await config.saveConfig(email, TestFixtures.testPassword);

          expect(container.read(authProvider).value?.email, email);
        });
      }

      test('saves the plugs, then signs in', () async {
        final config = await loaded();
        config.addDeviceIp(_ip);

        await config.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        // The home screen loads the plugs as soon as the account is saved.
        verifyInOrder([
          storage.saveDeviceIps([_ip]),
          storage.saveCredentials(
            TestFixtures.testEmail,
            TestFixtures.testPassword,
          ),
        ]);
        expect(container.read(authProvider).value, (
          email: TestFixtures.testEmail,
          password: TestFixtures.testPassword,
        ));
        expect(state().isSaving, isFalse);
      });

      test('shows the spinner while saving', () async {
        final config = await loaded();
        final saved = Completer<void>();
        when(storage.saveDeviceIps(any)).thenAnswer((_) => saved.future);

        final save = config.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(state().isSaving, isTrue);
        saved.complete();
        await save;
      });

      test('reports a storage failure and stays signed out', () async {
        final config = await loaded();
        when(storage.saveDeviceIps(any)).thenThrow(Exception('Storage error'));

        await config.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(state().errorMessage, 'Failed to save configuration');
        expect(state().isSaving, isFalse);
        expect(container.read(authProvider).value, isNull);
      });
    });

    group('addDeviceIp', () {
      test('adds valid IPs, trimmed', () async {
        final config = await loaded();

        config
          ..addDeviceIp('  $_ip  ')
          ..addDeviceIp(_ip2);

        expect(state().deviceIps, [_ip, _ip2]);
      });

      for (final (ip, error) in [
        ('', 'IP address cannot be empty'),
        ('   ', 'IP address cannot be empty'),
        ('not-an-ip', 'Invalid IP address format'),
        ('192.168.1.256', 'Invalid IP address format'),
      ]) {
        test('rejects "$ip": $error', () async {
          final config = await loaded();

          config.addDeviceIp(ip);

          expect(state().deviceIps, isEmpty);
          expect(state().errorMessage, error);
        });
      }

      test('rejects a duplicate IP', () async {
        final config = await loaded();

        config
          ..addDeviceIp(_ip)
          ..addDeviceIp(_ip);

        expect(state().deviceIps, [_ip]);
        expect(state().errorMessage, 'IP address already added');
      });

      test('clears the error on a successful add', () async {
        final config = await loaded();

        config
          ..addDeviceIp('invalid')
          ..addDeviceIp(_ip);

        expect(state().errorMessage, isNull);
      });
    });

    group('removeDeviceIp', () {
      test('removes the IP from the list', () async {
        final config = await loaded();

        config
          ..addDeviceIp(_ip)
          ..addDeviceIp(_ip2)
          ..removeDeviceIp(_ip);

        expect(state().deviceIps, [_ip2]);
      });

      test('ignores an IP that is not in the list', () async {
        final config = await loaded();

        config
          ..addDeviceIp(_ip)
          ..removeDeviceIp(_ip2);

        expect(state().deviceIps, [_ip]);
      });
    });
  });
}
