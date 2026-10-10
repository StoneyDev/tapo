import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/services/desktop_shell.dart';

/// "Lancer au démarrage" setting, shared by the tray menu and the window.
class LaunchAtStartupViewModel extends ChangeNotifier {
  LaunchAtStartupViewModel({DesktopShell? shell})
    : _shell = shell ?? GetIt.instance<DesktopShell>();

  final DesktopShell _shell;
  bool _enabled = false;

  bool get isEnabled => _enabled;

  Future<void> load() async {
    _enabled = await _shell.isLaunchAtStartupEnabled();
    notifyListeners();
  }

  Future<void> setEnabled({required bool enabled}) async {
    try {
      await _shell.setLaunchAtStartup(enabled: enabled);
      _enabled = enabled;
    } on PlatformException {
      // Registry write refused: keep showing the actual state.
    }
    notifyListeners();
  }
}
