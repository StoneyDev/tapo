import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolt/providers/services.dart';

typedef Credentials = ({String email, String password});

/// The signed-in Tapo account, null when signed out.
///
/// The app shows the home screen when signed in and the configuration screen
/// otherwise.
final authProvider = AsyncNotifierProvider<AuthNotifier, Credentials?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<Credentials?> {
  @override
  Future<Credentials?> build() async {
    try {
      final (:email, :password) = await ref
          .read(secureStorageProvider)
          .getCredentials();
      if (email == null || password == null) return null;
      return (email: email, password: password);
    } on Exception {
      // Unreadable storage: sign in again.
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    await ref.read(secureStorageProvider).saveCredentials(email, password);
    state = AsyncData((email: email, password: password));
  }

  /// Forgets the account and its plugs, closes the plug sessions, then
  /// clears the home screen widgets.
  Future<void> logout() async {
    // Cleared first: the configuration screen shown next reads the storage.
    final storage = ref.read(secureStorageProvider);
    await Future.wait([storage.clearCredentials(), storage.clearDeviceIps()]);

    // Ends the session: from here, work started for this account (loads,
    // toggles, countdowns) publishes nothing, so the widgets stay cleared.
    state = const AsyncData(null);

    final widgetData = ref.read(widgetDataProvider);
    await widgetData.clearWidgetData();
    await widgetData.refreshWidgets();
  }
}
