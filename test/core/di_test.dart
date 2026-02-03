import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/core/di.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';
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
    test('registers all services as lazy singletons (not TapoService)', () {
      setupLocator();

      // All registered
      expect(testGetIt.isRegistered<SecureStorageService>(), isTrue);
      expect(testGetIt.isRegistered<WidgetDataService>(), isTrue);
      expect(testGetIt.isRegistered<ConfigViewModel>(), isTrue);
      expect(testGetIt.isRegistered<HomeViewModel>(), isTrue);
      expect(testGetIt.isRegistered<TapoService>(), isFalse);

      // Verify singleton behavior
      expect(
        identical(testGetIt<SecureStorageService>(),
            testGetIt<SecureStorageService>()),
        isTrue,
      );
      expect(
        identical(testGetIt<WidgetDataService>(),
            testGetIt<WidgetDataService>()),
        isTrue,
      );
      expect(
        identical(testGetIt<ConfigViewModel>(),
            testGetIt<ConfigViewModel>()),
        isTrue,
      );
      expect(
        identical(testGetIt<HomeViewModel>(),
            testGetIt<HomeViewModel>()),
        isTrue,
      );
    });
  });

  group('registerTapoService', () {
    test('registers TapoService as lazy singleton', () {
      registerTapoService('test@example.com', 'password123');

      expect(testGetIt.isRegistered<TapoService>(), isTrue);
      expect(
        identical(
            testGetIt<TapoService>(), testGetIt<TapoService>()),
        isTrue,
      );
    });

    test('re-registration replaces existing service with new instance', () {
      registerTapoService('user1@example.com', 'password1');
      final service1 = testGetIt<TapoService>();

      registerTapoService('user2@example.com', 'password2');
      final service2 = testGetIt<TapoService>();

      expect(identical(service1, service2), isFalse);
    });

    test('works after setupLocator', () {
      setupLocator();
      registerTapoService('test@example.com', 'password123');

      expect(testGetIt.isRegistered<TapoService>(), isTrue);
    });
  });

  group('getIt global instance', () {
    test('getIt is GetIt.instance', () {
      expect(identical(getIt, GetIt.instance), isTrue);
    });
  });
}
