import 'package:flutter/services.dart';

/// An entry of the native tray context menu.
sealed class TrayMenuEntry {
  const TrayMenuEntry();

  Map<String, Object> toMap();
}

class TrayMenuItem extends TrayMenuEntry {
  const TrayMenuItem({
    required this.id,
    required this.label,
    this.checked = false,
    this.enabled = true,
  });

  final int id;
  final String label;
  final bool checked;
  final bool enabled;

  @override
  Map<String, Object> toMap() => {
    'id': id,
    'label': label,
    'checked': checked,
    'enabled': enabled,
  };
}

class TrayMenuSeparator extends TrayMenuEntry {
  const TrayMenuSeparator();

  @override
  Map<String, Object> toMap() => {'separator': true};
}

/// Bridge to the Windows runner (windows/runner/flutter_window.cpp):
/// tray icon, main window and launch at startup.
class DesktopShell {
  DesktopShell({this._channel = const MethodChannel('jolt/desktop')});

  final MethodChannel _channel;

  /// Native events: right click on the tray icon and menu item selection.
  void setTrayHandlers({
    required Future<void> Function() onMenuRequested,
    required Future<void> Function(int id) onMenuItemSelected,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'trayMenuRequested':
          await onMenuRequested();
        case 'trayMenuItemSelected':
          await onMenuItemSelected(call.arguments as int);
      }
    });
  }

  /// Shows [entries] as a context menu at the cursor position.
  Future<void> showTrayMenu(List<TrayMenuEntry> entries) =>
      _channel.invokeMethod('showTrayMenu', [
        for (final entry in entries) entry.toMap(),
      ]);

  Future<void> setTrayTooltip(String tooltip) =>
      _channel.invokeMethod('setTrayTooltip', tooltip);

  Future<void> showNotification({
    required String title,
    required String message,
  }) => _channel.invokeMethod('showNotification', {
    'title': title,
    'message': message,
  });

  Future<void> showWindow() => _channel.invokeMethod('showWindow');

  /// Closes the window for real and exits the process.
  Future<void> quit() => _channel.invokeMethod('quit');

  Future<bool> isLaunchAtStartupEnabled() async =>
      await _channel.invokeMethod<bool>('getLaunchAtStartup') ?? false;

  Future<void> setLaunchAtStartup({required bool enabled}) =>
      _channel.invokeMethod('setLaunchAtStartup', enabled);
}
