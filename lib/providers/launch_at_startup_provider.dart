import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolt/providers/services.dart';

/// "Lancer au démarrage" setting, shared by the tray menu and the window.
final launchAtStartupProvider =
    AsyncNotifierProvider<LaunchAtStartupNotifier, bool>(
      LaunchAtStartupNotifier.new,
    );

class LaunchAtStartupNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.read(desktopShellProvider).isLaunchAtStartupEnabled();

  Future<void> setEnabled({required bool enabled}) async {
    try {
      await ref.read(desktopShellProvider).setLaunchAtStartup(enabled: enabled);
      state = AsyncData(enabled);
    } on PlatformException {
      // Registry write refused: keep showing the actual state.
    }
  }
}
