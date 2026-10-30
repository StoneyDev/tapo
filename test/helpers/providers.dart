import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:jolt/providers/auth_provider.dart';
import 'package:jolt/providers/home_provider.dart';
import 'package:jolt/providers/services.dart';
import 'package:jolt/services/secure_storage_service.dart';
import 'package:jolt/services/tapo_service.dart';
import 'package:jolt/services/widget_data_service.dart';
import 'package:mockito/mockito.dart';

import 'test_utils.dart';
import 'test_utils.mocks.dart';

/// Widget storage that accepts every write.
MockWidgetDataService stubbedWidgetData() {
  final widgetData = MockWidgetDataService();
  when(widgetData.saveAllDevices(any)).thenAnswer((_) async {});
  when(widgetData.refreshWidgets()).thenAnswer((_) async {});
  when(widgetData.clearWidgetData()).thenAnswer((_) async {});
  when(
    widgetData.saveDeviceState(
      ip: anyNamed('ip'),
      model: anyNamed('model'),
      nickname: anyNamed('nickname'),
      deviceOn: anyNamed('deviceOn'),
      isOnline: anyNamed('isOnline'),
    ),
  ).thenAnswer((_) async {});
  return widgetData;
}

/// Storage without account nor plugs that accepts every write.
MockSecureStorageService stubbedStorage() {
  final storage = MockSecureStorageService();
  stubSignedOut(storage);
  when(storage.getDeviceIps()).thenAnswer((_) async => []);
  when(storage.saveCredentials(any, any)).thenAnswer((_) async {});
  when(storage.saveDeviceIps(any)).thenAnswer((_) async {});
  when(storage.clearCredentials()).thenAnswer((_) async {});
  when(storage.clearDeviceIps()).thenAnswer((_) async {});
  return storage;
}

/// Stores the test account, so [authProvider] starts signed in.
void stubSignedIn(MockSecureStorageService storage) {
  when(storage.getCredentials()).thenAnswer(
    (_) async =>
        (email: TestFixtures.testEmail, password: TestFixtures.testPassword),
  );
}

void stubSignedOut(MockSecureStorageService storage) {
  when(
    storage.getCredentials(),
  ).thenAnswer((_) async => (email: null, password: null));
}

/// Signs in with the stored account and waits for the first load of the
/// plugs.
Future<HomeNotifier> signIn(ProviderContainer container) async {
  await container.read(authProvider.future);
  final home = container.read(homeProvider.notifier);
  await home.refresh(silent: true); // Joins the first load.
  return home;
}

/// Real auth on [storage]; [tapo] plays the plug service of whichever
/// account is signed in.
List<Override> appOverrides({
  required SecureStorageService storage,
  required TapoService tapo,
  WidgetDataService? widgetData,
}) => [
  secureStorageProvider.overrideWithValue(storage),
  widgetDataProvider.overrideWithValue(widgetData ?? stubbedWidgetData()),
  tapoServiceProvider.overrideWith(
    (ref) => ref.watch(authProvider).value == null ? null : tapo,
  ),
];
