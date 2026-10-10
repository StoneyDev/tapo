import 'dart:async';

import 'package:tapo/services/desktop_shell.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/viewmodels/launch_at_startup_viewmodel.dart';

/// Drives the Windows tray icon: quick plug toggles from the context menu
/// (like Steam or Discord) and a tooltip summarising the plugs.
///
/// [HomeViewModel] stays the single source of truth so the tray and the
/// window always agree.
class TrayController {
  TrayController({
    required DesktopShell shell,
    required HomeViewModel home,
    required LaunchAtStartupViewModel launchAtStartup,
    Duration refreshBudget = const Duration(milliseconds: 450),
  }) : _shell = shell,
       _home = home,
       _launchAtStartup = launchAtStartup,
       _refreshBudget = refreshBudget;

  final DesktopShell _shell;
  final HomeViewModel _home;
  final LaunchAtStartupViewModel _launchAtStartup;

  /// How long a right click may wait for fresh plug states before the menu
  /// opens with the last known ones. Established LAN sessions answer in
  /// ~50 ms; unreachable plugs must not make the menu feel sluggish.
  final Duration _refreshBudget;

  static const _openId = 1;
  static const _turnOffAllId = 2;
  static const _launchAtStartupId = 3;
  static const _quitId = 4;
  static const _firstDeviceId = 100;

  /// Plug IPs by menu id, from the last menu shown.
  Map<int, String> _menuDevices = const {};
  String? _tooltip;

  Future<void> start() async {
    _shell.setTrayHandlers(
      onMenuRequested: _showMenu,
      onMenuItemSelected: _onMenuItemSelected,
    );
    _home.addListener(_syncTooltip);
    _syncTooltip();
    await _launchAtStartup.load();
  }

  String get _summary {
    final devices = _home.devices;
    if (devices.isEmpty) return 'Tapo · aucune prise';
    final on = devices.where((d) => d.isOnline && d.deviceOn).length;
    return 'Tapo · $on/${devices.length} allumées';
  }

  void _syncTooltip() {
    final tooltip = _summary;
    if (tooltip == _tooltip) return;
    _tooltip = tooltip;
    unawaited(_shell.setTrayTooltip(tooltip));
  }

  Future<void> _showMenu() async {
    await Future.wait([
      _home.refresh(silent: true).timeout(_refreshBudget, onTimeout: () {}),
      // Cheap registry read: the user may have changed it in Task Manager.
      _launchAtStartup.load(),
    ]);

    final devices = _home.devices;
    _menuDevices = {
      for (final (index, device) in devices.indexed)
        _firstDeviceId + index: device.ip,
    };

    await _shell.showTrayMenu([
      TrayMenuItem(id: 0, label: _summary, enabled: false),
      const TrayMenuSeparator(),
      if (devices.isNotEmpty) ...[
        for (final (index, device) in devices.indexed)
          TrayMenuItem(
            id: _firstDeviceId + index,
            label: device.isOnline
                ? device.nickname
                : '${device.nickname} — hors ligne',
            checked: device.isOnline && device.deviceOn,
            enabled: device.isOnline && !_home.isToggling(device.ip),
          ),
        const TrayMenuSeparator(),
        TrayMenuItem(
          id: _turnOffAllId,
          label: 'Tout éteindre',
          enabled: devices.any((d) => d.isOnline && d.deviceOn),
        ),
        const TrayMenuSeparator(),
      ],
      const TrayMenuItem(id: _openId, label: 'Ouvrir Tapo'),
      TrayMenuItem(
        id: _launchAtStartupId,
        label: 'Lancer au démarrage',
        checked: _launchAtStartup.isEnabled,
      ),
      const TrayMenuItem(id: _quitId, label: 'Quitter'),
    ]);
  }

  Future<void> _onMenuItemSelected(int id) async {
    switch (id) {
      case _openId:
        await _shell.showWindow();
      case _turnOffAllId:
        await _home.turnOffAll();
      case _launchAtStartupId:
        await _launchAtStartup.setEnabled(enabled: !_launchAtStartup.isEnabled);
      case _quitId:
        await _shell.quit();
      default:
        final ip = _menuDevices[id];
        if (ip != null) await _toggle(ip);
    }
  }

  Future<void> _toggle(String ip) async {
    if (await _home.toggleDevice(ip)) return;

    final device = _home.devices.where((d) => d.ip == ip).firstOrNull;
    await _shell.showNotification(
      title: 'Tapo',
      message: '${device?.nickname ?? ip} est injoignable',
    );
  }
}
