import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/core/di.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';

void main() {
  // Use the global getIt instance from di.dart
  late GetIt testGetIt;

  setUp(() async {
    // Reset the global instance before each test
    testGetIt = GetIt.instance;
    await testGetIt.reset();
  });

  tearDown(() async {
    await testGetIt.reset();
  });

  group('setupLocator', () {
    test('registers SecureStorageService as lazy singleton', () {
      setupLocator();

      expect(testGetIt.isRegistered<SecureStorageService>(), isTrue);
      final service1 = testGetIt<SecureStorageService>();
      final service2 = testGetIt<SecureStorageService>();
      expect(identical(service1, service2), isTrue);
    });

    test('registers ConfigViewModel as lazy singleton', () {
      setupLocator();

      expect(testGetIt.isRegistered<ConfigViewModel>(), isTrue);
      final vm1 = testGetIt<ConfigViewModel>();
      final vm2 = testGetIt<ConfigViewModel>();
      expect(identical(vm1, vm2), isTrue);
    });

    test('registers HomeViewModel as lazy singleton', () {
      setupLocator();

      expect(testGetIt.isRegistered<HomeViewModel>(), isTrue);
      final vm1 = testGetIt<HomeViewModel>();
      final vm2 = testGetIt<HomeViewModel>();
      expect(identical(vm1, vm2), isTrue);
    });

    test('registers all three services', () {
      setupLocator();

      expect(testGetIt.isRegistered<SecureStorageService>(), isTrue);
      expect(testGetIt.isRegistered<ConfigViewModel>(), isTrue);
      expect(testGetIt.isRegistered<HomeViewModel>(), isTrue);
    });

    test('does not register TapoService', () {
      setupLocator();

      expect(testGetIt.isRegistered<TapoService>(), isFalse);
    });
  });

  group('registerTapoService', () {
    test('registers TapoService with credentials', () {
      registerTapoService('test@example.com', 'password123');

      expect(testGetIt.isRegistered<TapoService>(), isTrue);
    });

    test('TapoService is lazy singleton (same instance on multiple gets)', () {
      registerTapoService('test@example.com', 'password123');

      final service1 = testGetIt<TapoService>();
      final service2 = testGetIt<TapoService>();
      expect(identical(service1, service2), isTrue);
    });

    test('re-registration replaces existing service', () {
      registerTapoService('user1@example.com', 'password1');
      final service1 = testGetIt<TapoService>();

      registerTapoService('user2@example.com', 'password2');
      final service2 = testGetIt<TapoService>();

      // New instance after re-registration
      expect(identical(service1, service2), isFalse);
    });

    test('re-registration does not throw', () {
      expect(
        () {
          registerTapoService('user1@example.com', 'password1');
          registerTapoService('user2@example.com', 'password2');
        },
        returnsNormally,
      );
    });

    test('can register after setupLocator', () {
      setupLocator();
      registerTapoService('test@example.com', 'password123');

      expect(testGetIt.isRegistered<SecureStorageService>(), isTrue);
      expect(testGetIt.isRegistered<ConfigViewModel>(), isTrue);
      expect(testGetIt.isRegistered<HomeViewModel>(), isTrue);
      expect(testGetIt.isRegistered<TapoService>(), isTrue);
    });
  });

  group('getIt global instance', () {
    test('getIt is GetIt.instance', () {
      expect(identical(getIt, GetIt.instance), isTrue);
    });
  });
}
