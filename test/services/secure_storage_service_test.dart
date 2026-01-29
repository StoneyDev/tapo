import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/services/secure_storage_service.dart';

import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

/// Testable subclass that allows injecting a mock FlutterSecureStorage
class TestableSecureStorageService extends SecureStorageService {
  final FlutterSecureStorage mockStorage;

  TestableSecureStorageService(this.mockStorage);

  @override
  FlutterSecureStorage get storage => mockStorage;
}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late TestableSecureStorageService service;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    service = TestableSecureStorageService(mockStorage);
  });

  group('SecureStorageService', () {
    group('constructor', () {
      test('creates instance without error', () {
        expect(service, isNotNull);
        expect(service, isA<SecureStorageService>());
      });
    });

    group('saveCredentials', () {
      test('writes email and password to storage', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        await service.saveCredentials(
            TestFixtures.testEmail, TestFixtures.testPassword);

        verify(mockStorage.write(key: 'tapo_email', value: TestFixtures.testEmail))
            .called(1);
        verify(mockStorage.write(
                key: 'tapo_password', value: TestFixtures.testPassword))
            .called(1);
      });

      test('saves empty credentials', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        await service.saveCredentials('', '');

        verify(mockStorage.write(key: 'tapo_email', value: '')).called(1);
        verify(mockStorage.write(key: 'tapo_password', value: '')).called(1);
      });

      test('saves credentials with special characters', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        const specialEmail = 'user+test@example.com';
        const specialPassword = 'p@ss!w0rd#\$%^&*()';

        await service.saveCredentials(specialEmail, specialPassword);

        verify(mockStorage.write(key: 'tapo_email', value: specialEmail))
            .called(1);
        verify(mockStorage.write(key: 'tapo_password', value: specialPassword))
            .called(1);
      });
    });

    group('getCredentials', () {
      test('returns stored email and password', () async {
        when(mockStorage.read(key: 'tapo_email'))
            .thenAnswer((_) async => TestFixtures.testEmail);
        when(mockStorage.read(key: 'tapo_password'))
            .thenAnswer((_) async => TestFixtures.testPassword);

        final result = await service.getCredentials();

        expect(result.email, TestFixtures.testEmail);
        expect(result.password, TestFixtures.testPassword);
      });

      test('returns null email when not stored', () async {
        when(mockStorage.read(key: 'tapo_email')).thenAnswer((_) async => null);
        when(mockStorage.read(key: 'tapo_password'))
            .thenAnswer((_) async => TestFixtures.testPassword);

        final result = await service.getCredentials();

        expect(result.email, isNull);
        expect(result.password, TestFixtures.testPassword);
      });

      test('returns null password when not stored', () async {
        when(mockStorage.read(key: 'tapo_email'))
            .thenAnswer((_) async => TestFixtures.testEmail);
        when(mockStorage.read(key: 'tapo_password'))
            .thenAnswer((_) async => null);

        final result = await service.getCredentials();

        expect(result.email, TestFixtures.testEmail);
        expect(result.password, isNull);
      });

      test('returns both null when storage empty', () async {
        when(mockStorage.read(key: 'tapo_email')).thenAnswer((_) async => null);
        when(mockStorage.read(key: 'tapo_password'))
            .thenAnswer((_) async => null);

        final result = await service.getCredentials();

        expect(result.email, isNull);
        expect(result.password, isNull);
      });
    });

    group('clearCredentials', () {
      test('deletes email and password from storage', () async {
        when(mockStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        await service.clearCredentials();

        verify(mockStorage.delete(key: 'tapo_email')).called(1);
        verify(mockStorage.delete(key: 'tapo_password')).called(1);
      });
    });

    group('hasCredentials', () {
      test('returns true when both email and password exist', () async {
        when(mockStorage.read(key: 'tapo_email'))
            .thenAnswer((_) async => TestFixtures.testEmail);
        when(mockStorage.read(key: 'tapo_password'))
            .thenAnswer((_) async => TestFixtures.testPassword);

        final result = await service.hasCredentials();

        expect(result, isTrue);
      });

      test('returns false when email is null', () async {
        when(mockStorage.read(key: 'tapo_email')).thenAnswer((_) async => null);
        when(mockStorage.read(key: 'tapo_password'))
            .thenAnswer((_) async => TestFixtures.testPassword);

        final result = await service.hasCredentials();

        expect(result, isFalse);
      });

      test('returns false when password is null', () async {
        when(mockStorage.read(key: 'tapo_email'))
            .thenAnswer((_) async => TestFixtures.testEmail);
        when(mockStorage.read(key: 'tapo_password'))
            .thenAnswer((_) async => null);

        final result = await service.hasCredentials();

        expect(result, isFalse);
      });

      test('returns false when both are null', () async {
        when(mockStorage.read(key: 'tapo_email')).thenAnswer((_) async => null);
        when(mockStorage.read(key: 'tapo_password'))
            .thenAnswer((_) async => null);

        final result = await service.hasCredentials();

        expect(result, isFalse);
      });
    });

    group('saveDeviceIps', () {
      test('writes JSON encoded IP list to storage', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        final ips = [TestFixtures.testDeviceIp, TestFixtures.testDeviceIp2];
        await service.saveDeviceIps(ips);

        verify(mockStorage.write(
          key: 'tapo_device_ips',
          value: jsonEncode(ips),
        )).called(1);
      });

      test('saves empty list', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        await service.saveDeviceIps([]);

        verify(mockStorage.write(
          key: 'tapo_device_ips',
          value: '[]',
        )).called(1);
      });

      test('saves single IP', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        await service.saveDeviceIps([TestFixtures.testDeviceIp]);

        verify(mockStorage.write(
          key: 'tapo_device_ips',
          value: '["${TestFixtures.testDeviceIp}"]',
        )).called(1);
      });
    });

    group('getDeviceIps', () {
      test('returns decoded IP list from storage', () async {
        final ips = [TestFixtures.testDeviceIp, TestFixtures.testDeviceIp2];
        when(mockStorage.read(key: 'tapo_device_ips'))
            .thenAnswer((_) async => jsonEncode(ips));

        final result = await service.getDeviceIps();

        expect(result, equals(ips));
      });

      test('returns empty list when storage is null', () async {
        when(mockStorage.read(key: 'tapo_device_ips'))
            .thenAnswer((_) async => null);

        final result = await service.getDeviceIps();

        expect(result, isEmpty);
      });

      test('returns empty list when stored as empty array', () async {
        when(mockStorage.read(key: 'tapo_device_ips'))
            .thenAnswer((_) async => '[]');

        final result = await service.getDeviceIps();

        expect(result, isEmpty);
      });

      test('returns single IP from storage', () async {
        when(mockStorage.read(key: 'tapo_device_ips'))
            .thenAnswer((_) async => '["${TestFixtures.testDeviceIp}"]');

        final result = await service.getDeviceIps();

        expect(result, equals([TestFixtures.testDeviceIp]));
      });
    });

    group('clearDeviceIps', () {
      test('deletes device IPs from storage', () async {
        when(mockStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        await service.clearDeviceIps();

        verify(mockStorage.delete(key: 'tapo_device_ips')).called(1);
      });
    });
  });
}
