import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapo/providers/auth_provider.dart';
import 'package:tapo/services/desktop_shell.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final widgetDataProvider = Provider<WidgetDataService>(
  (ref) => WidgetDataService(),
);

/// Desktop only: the runner channel is never called on mobile.
final desktopShellProvider = Provider<DesktopShell>((ref) => DesktopShell());

/// Talks to the plugs with the signed-in account; null when signed out.
///
/// Signing out or in with another account disposes the service, which closes
/// its plug sessions.
final tapoServiceProvider = Provider<TapoService?>((ref) {
  final credentials = ref.watch(authProvider.select((auth) => auth.value));
  if (credentials == null) return null;

  final service = TapoService.fromCredentials(
    credentials.email,
    credentials.password,
  );
  ref.onDispose(() => unawaited(service.disconnectAll()));
  return service;
});
