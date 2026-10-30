import 'package:flutter/services.dart';
import 'package:jolt/services/desktop_shell.dart';

/// In-memory stand-in for the Windows runner behind [DesktopShell].
class FakeDesktopShell implements DesktopShell {
  bool launchAtStartup = false;
  bool failLaunchAtStartupWrites = false;

  final List<List<TrayMenuEntry>> menus = [];
  final List<String> tooltips = [];
  final List<({String title, String message})> notifications = [];
  int showWindowCalls = 0;
  int quitCalls = 0;

  late Future<void> Function() _onMenuRequested;
  late Future<void> Function(int id) _onMenuItemSelected;

  /// Simulates a right click on the tray icon.
  Future<void> rightClickTray() => _onMenuRequested();

  /// Simulates choosing the menu item labelled [label] in the last menu.
  Future<void> select(String label) {
    final item = menus.last.whereType<TrayMenuItem>().firstWhere(
      (item) => item.label == label,
    );
    return _onMenuItemSelected(item.id);
  }

  @override
  void setTrayHandlers({
    required Future<void> Function() onMenuRequested,
    required Future<void> Function(int id) onMenuItemSelected,
  }) {
    _onMenuRequested = onMenuRequested;
    _onMenuItemSelected = onMenuItemSelected;
  }

  @override
  Future<void> showTrayMenu(List<TrayMenuEntry> entries) async =>
      menus.add(entries);

  @override
  Future<void> setTrayTooltip(String tooltip) async => tooltips.add(tooltip);

  @override
  Future<void> showNotification({
    required String title,
    required String message,
  }) async => notifications.add((title: title, message: message));

  @override
  Future<void> showWindow() async => showWindowCalls++;

  @override
  Future<void> quit() async => quitCalls++;

  @override
  Future<bool> isLaunchAtStartupEnabled() async => launchAtStartup;

  @override
  Future<void> setLaunchAtStartup({required bool enabled}) async {
    if (failLaunchAtStartupWrites) {
      throw PlatformException(code: 'registry');
    }
    launchAtStartup = enabled;
  }
}
