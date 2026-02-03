import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';

import '../helpers/test_utils.dart';
import '../helpers/test_utils.mocks.dart';

void main() {
  late MockSecureStorageService mockStorageService;
  late ConfigViewModel viewModel;

  setUp(() {
    mockStorageService = MockSecureStorageService();
    viewModel = ConfigViewModel(storageService: mockStorageService);

    // Reset GetIt for each test to avoid TapoService registration conflicts
    final getIt = GetIt.instance;
    if (getIt.isRegistered<TapoService>()) {
      getIt.unregister<TapoService>();
    }
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<TapoService>()) {
      getIt.unregister<TapoService>();
    }
  });

  group('ConfigViewModel', () {
    group('constructor', () {
      test('creates instance with injected storage service', () {
        expect(viewModel, isNotNull);
        expect(viewModel, isA<ConfigViewModel>());
      });

      test('initializes with empty deviceIps', () {
        expect(viewModel.deviceIps, isEmpty);
      });

      test('initializes with isLoading false', () {
        expect(viewModel.isLoading, isFalse);
      });

      test('initializes with errorMessage null', () {
        expect(viewModel.errorMessage, isNull);
      });
    });

    group('loadConfig', () {
      test('fetches credentials and device IPs from storage', () async {
        when(mockStorageService.getCredentials()).thenAnswer(
          (_) async => (
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword,
          ),
        );
        when(
          mockStorageService.getDeviceIps(),
        ).thenAnswer((_) async => [TestFixtures.testDeviceIp]);

        final result = await viewModel.loadConfig();

        expect(result.email, TestFixtures.testEmail);
        expect(result.password, TestFixtures.testPassword);
        expect(viewModel.deviceIps, [TestFixtures.testDeviceIp]);
        verify(mockStorageService.getCredentials()).called(1);
        verify(mockStorageService.getDeviceIps()).called(1);
      });

      test('returns empty strings when credentials are null', () async {
        when(
          mockStorageService.getCredentials(),
        ).thenAnswer((_) async => (email: null, password: null));
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        final result = await viewModel.loadConfig();

        expect(result.email, '');
        expect(result.password, '');
      });

      test('notifies listeners when loading starts and finishes', () async {
        when(mockStorageService.getCredentials()).thenAnswer(
          (_) async => (
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword,
          ),
        );
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        final notifications = <bool>[];
        viewModel.addListener(() {
          notifications.add(viewModel.isLoading);
        });

        await viewModel.loadConfig();

        // Should have notified twice: loading=true, then loading=false
        expect(notifications, [true, false]);
      });

      test('sets isLoading true during load', () async {
        var loadingDuringFetch = false;
        when(mockStorageService.getCredentials()).thenAnswer((_) async {
          loadingDuringFetch = viewModel.isLoading;
          return (
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword,
          );
        });
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        await viewModel.loadConfig();

        expect(loadingDuringFetch, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('sets errorMessage on exception', () async {
        when(
          mockStorageService.getCredentials(),
        ).thenThrow(Exception('Storage error'));

        final result = await viewModel.loadConfig();

        expect(result.email, '');
        expect(result.password, '');
        expect(viewModel.errorMessage, 'Failed to load configuration');
      });

      test('clears errorMessage on successful load', () async {
        // First trigger an error
        when(mockStorageService.getCredentials()).thenThrow(Exception('Error'));
        await viewModel.loadConfig();
        expect(viewModel.errorMessage, isNotNull);

        // Then successful load
        when(mockStorageService.getCredentials()).thenAnswer(
          (_) async => (
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword,
          ),
        );
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        await viewModel.loadConfig();

        expect(viewModel.errorMessage, isNull);
      });
    });

    group('saveConfig', () {
      test('validates empty email', () async {
        final result = await viewModel.saveConfig(
          '',
          TestFixtures.testPassword,
        );

        expect(result, isFalse);
        expect(viewModel.errorMessage, 'Email and password required');
        verifyNever(mockStorageService.saveCredentials(any, any));
      });

      test('validates empty password', () async {
        final result = await viewModel.saveConfig(TestFixtures.testEmail, '');

        expect(result, isFalse);
        expect(viewModel.errorMessage, 'Email and password required');
      });

      test('validates invalid email format', () async {
        final result = await viewModel.saveConfig(
          'invalid-email',
          TestFixtures.testPassword,
        );

        expect(result, isFalse);
        expect(viewModel.errorMessage, 'Invalid email format');
      });

      test('validates password minimum length', () async {
        final result = await viewModel.saveConfig(
          TestFixtures.testEmail,
          'short',
        );

        expect(result, isFalse);
        expect(
          viewModel.errorMessage,
          'Password must be at least 8 characters',
        );
      });

      test('saves credentials and device IPs on valid input', () async {
        when(
          mockStorageService.saveCredentials(any, any),
        ).thenAnswer((_) async {});
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});

        final result = await viewModel.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(result, isTrue);
        verify(
          mockStorageService.saveCredentials(
            TestFixtures.testEmail,
            TestFixtures.testPassword,
          ),
        ).called(1);
        verify(mockStorageService.saveDeviceIps(any)).called(1);
      });

      test('registers TapoService after saving', () async {
        when(
          mockStorageService.saveCredentials(any, any),
        ).thenAnswer((_) async {});
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});

        await viewModel.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        // Verify TapoService was registered
        expect(GetIt.instance.isRegistered<TapoService>(), isTrue);
      });

      test('notifies listeners during save', () async {
        when(
          mockStorageService.saveCredentials(any, any),
        ).thenAnswer((_) async {});
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});

        final notifications = <bool>[];
        viewModel.addListener(() {
          notifications.add(viewModel.isLoading);
        });

        await viewModel.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(notifications, [true, false]);
      });

      test('sets errorMessage on save exception', () async {
        when(
          mockStorageService.saveCredentials(any, any),
        ).thenThrow(Exception('Save failed'));

        final result = await viewModel.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(result, isFalse);
        expect(viewModel.errorMessage, 'Failed to save configuration');
      });

      test('accepts valid email formats', () async {
        when(
          mockStorageService.saveCredentials(any, any),
        ).thenAnswer((_) async {});
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});

        final validEmails = [
          'user@example.com',
          'user.name@example.com',
          'user+tag@example.co.uk',
        ];

        for (final email in validEmails) {
          final result = await viewModel.saveConfig(
            email,
            TestFixtures.testPassword,
          );
          expect(result, isTrue, reason: 'Email $email should be valid');
        }
      });
    });

    group('addDeviceIp', () {
      test('adds valid IP to list', () {
        viewModel.addDeviceIp(TestFixtures.testDeviceIp);

        expect(viewModel.deviceIps, [TestFixtures.testDeviceIp]);
      });

      test('trims whitespace from IP', () {
        viewModel.addDeviceIp('  ${TestFixtures.testDeviceIp}  ');

        expect(viewModel.deviceIps, [TestFixtures.testDeviceIp]);
      });

      test('notifies listeners on add', () {
        var notified = false;
        viewModel
          ..addListener(() => notified = true)
          ..addDeviceIp(TestFixtures.testDeviceIp);

        expect(notified, isTrue);
      });

      test('sets error for empty IP', () {
        viewModel.addDeviceIp('');

        expect(viewModel.deviceIps, isEmpty);
        expect(viewModel.errorMessage, 'IP address cannot be empty');
      });

      test('sets error for whitespace-only IP', () {
        viewModel.addDeviceIp('   ');

        expect(viewModel.deviceIps, isEmpty);
        expect(viewModel.errorMessage, 'IP address cannot be empty');
      });

      test('sets error for invalid IP format', () {
        viewModel.addDeviceIp('not-an-ip');

        expect(viewModel.deviceIps, isEmpty);
        expect(viewModel.errorMessage, 'Invalid IP address format');
      });

      test('sets error for IP with invalid octet', () {
        viewModel.addDeviceIp('192.168.1.256');

        expect(viewModel.deviceIps, isEmpty);
        expect(viewModel.errorMessage, 'Invalid IP address format');
      });

      test('sets error for duplicate IP', () {
        viewModel
          ..addDeviceIp(TestFixtures.testDeviceIp)
          ..addDeviceIp(TestFixtures.testDeviceIp);

        expect(viewModel.deviceIps.length, 1);
        expect(viewModel.errorMessage, 'IP address already added');
      });

      test('clears error on successful add', () {
        // First add invalid to set error
        viewModel.addDeviceIp('invalid');
        expect(viewModel.errorMessage, isNotNull);

        // Then add valid
        viewModel.addDeviceIp(TestFixtures.testDeviceIp);
        expect(viewModel.errorMessage, isNull);
      });

      test('allows multiple different IPs', () {
        viewModel
          ..addDeviceIp(TestFixtures.testDeviceIp)
          ..addDeviceIp(TestFixtures.testDeviceIp2);

        expect(viewModel.deviceIps, [
          TestFixtures.testDeviceIp,
          TestFixtures.testDeviceIp2,
        ]);
      });
    });

    group('removeDeviceIp', () {
      test('removes IP from list', () {
        viewModel
          ..addDeviceIp(TestFixtures.testDeviceIp)
          ..addDeviceIp(TestFixtures.testDeviceIp2)
          ..removeDeviceIp(TestFixtures.testDeviceIp);

        expect(viewModel.deviceIps, [TestFixtures.testDeviceIp2]);
      });

      test('notifies listeners on remove', () {
        viewModel.addDeviceIp(TestFixtures.testDeviceIp);

        var notified = false;
        viewModel
          ..addListener(() => notified = true)
          ..removeDeviceIp(TestFixtures.testDeviceIp);

        expect(notified, isTrue);
      });

      test('handles removing non-existent IP gracefully', () {
        viewModel
          ..addDeviceIp(TestFixtures.testDeviceIp)
          ..removeDeviceIp('10.0.0.1');

        expect(viewModel.deviceIps, [TestFixtures.testDeviceIp]);
      });

      test('results in empty list when last IP removed', () {
        viewModel
          ..addDeviceIp(TestFixtures.testDeviceIp)
          ..removeDeviceIp(TestFixtures.testDeviceIp);

        expect(viewModel.deviceIps, isEmpty);
      });
    });

    group('isLoading states', () {
      test('isLoading is false initially', () {
        expect(viewModel.isLoading, isFalse);
      });

      test('isLoading becomes true during loadConfig', () async {
        var wasLoadingDuringCall = false;

        when(mockStorageService.getCredentials()).thenAnswer((_) async {
          wasLoadingDuringCall = viewModel.isLoading;
          return (
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword,
          );
        });
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        await viewModel.loadConfig();

        expect(wasLoadingDuringCall, isTrue);
      });

      test('isLoading becomes false after loadConfig completes', () async {
        when(mockStorageService.getCredentials()).thenAnswer(
          (_) async => (
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword,
          ),
        );
        when(mockStorageService.getDeviceIps()).thenAnswer((_) async => []);

        await viewModel.loadConfig();

        expect(viewModel.isLoading, isFalse);
      });

      test('isLoading becomes false after loadConfig error', () async {
        when(mockStorageService.getCredentials()).thenThrow(Exception('Error'));

        await viewModel.loadConfig();

        expect(viewModel.isLoading, isFalse);
      });

      test('isLoading becomes true during saveConfig', () async {
        var wasLoadingDuringCall = false;

        when(mockStorageService.saveCredentials(any, any)).thenAnswer((
          _,
        ) async {
          wasLoadingDuringCall = viewModel.isLoading;
        });
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});

        await viewModel.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(wasLoadingDuringCall, isTrue);
      });

      test('isLoading becomes false after saveConfig completes', () async {
        when(
          mockStorageService.saveCredentials(any, any),
        ).thenAnswer((_) async {});
        when(mockStorageService.saveDeviceIps(any)).thenAnswer((_) async {});

        await viewModel.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(viewModel.isLoading, isFalse);
      });

      test('isLoading becomes false after saveConfig error', () async {
        when(
          mockStorageService.saveCredentials(any, any),
        ).thenThrow(Exception('Error'));

        await viewModel.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(viewModel.isLoading, isFalse);
      });
    });

    group('error handling', () {
      test('errorMessage is null initially', () {
        expect(viewModel.errorMessage, isNull);
      });

      test('errorMessage set on loadConfig failure', () async {
        when(mockStorageService.getCredentials()).thenThrow(Exception('Error'));

        await viewModel.loadConfig();

        expect(viewModel.errorMessage, 'Failed to load configuration');
      });

      test('errorMessage set on saveConfig validation failure', () async {
        await viewModel.saveConfig('', '');

        expect(viewModel.errorMessage, 'Email and password required');
      });

      test('errorMessage set on saveConfig storage failure', () async {
        when(
          mockStorageService.saveCredentials(any, any),
        ).thenThrow(Exception('Error'));

        await viewModel.saveConfig(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(viewModel.errorMessage, 'Failed to save configuration');
      });

      test('errorMessage set on addDeviceIp validation failure', () {
        viewModel.addDeviceIp('invalid-ip');

        expect(viewModel.errorMessage, 'Invalid IP address format');
      });

      test('errorMessage cleared on successful operations', () async {
        // Set error first
        viewModel.addDeviceIp('invalid');
        expect(viewModel.errorMessage, isNotNull);

        // Clear with successful add
        viewModel.addDeviceIp(TestFixtures.testDeviceIp);
        expect(viewModel.errorMessage, isNull);
      });

      test('notifies listeners when error is set', () {
        final errorMessages = <String?>[];
        viewModel
          ..addListener(() {
            errorMessages.add(viewModel.errorMessage);
          })
          ..addDeviceIp('invalid');

        expect(errorMessages, ['Invalid IP address format']);
      });
    });

    group('deviceIps immutability', () {
      test('deviceIps returns unmodifiable list', () {
        viewModel.addDeviceIp(TestFixtures.testDeviceIp);

        expect(
          () => viewModel.deviceIps.add('10.0.0.1'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });
  });
}
