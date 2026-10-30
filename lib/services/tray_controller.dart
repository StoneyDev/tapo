import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolt/models/tapo_device.dart';
import 'package:jolt/providers/home_provider.dart';
import 'package:jolt/providers/launch_at_startup_provider.dart';
import 'package:jolt/providers/services.dart';
import 'package:jolt/services/desktop_shell.dart';

final trayControllerProvider = Provider<TrayController>(TrayController.new);

/// Drives the Windows tray icon: quick plug toggles from the context menu
/// (like Steam or Discord) and a tooltip summarising the plugs.
///
/// [homeProvider] stays the single source of truth so the tray and the
/// window always agree.
class TrayController {
  TrayController(
    this._ref, {
    this._refreshBudget = const Duration(milliseconds: 450),
  });

  final Ref _ref;

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

  DesktopShell get _shell => _ref.read(desktopShellProvider);
  HomeNotifier get _home => _ref.read(homeProvider.notifier);
  bool get _launchAtStartup =>
      _ref.read(launchAtStartupProvider).value ?? false;

  void start() {
    _shell.setTrayHandlers(
      onMenuRequested: _showMenu,
      onMenuItemSelected: _onMenuItemSelected,
    );
    _ref.listen(
      homeProvider.select((home) => _summary(home.devices)),
      (_, tooltip) => unawaited(_shell.setTrayTooltip(tooltip)),
      fireImmediately: true,
    );
    // Loaded early, so the window's switch does not flip on its first frame.
    _ref.read(launchAtStartupProvider);
  }

  static String _summary(List<TapoDevice> devices) {
    if (devices.isEmpty) return 'Jolt · aucune prise';
    final on = devices.where((d) => d.isOnline && d.deviceOn).length;
    return 'Jolt · $on/${devices.length} allumées';
  }

  Future<void> _showMenu() async {
    await Future.wait([
      _home.refresh(silent: true).timeout(_refreshBudget, onTimeout: () {}),
      // Cheap registry read: the user may have changed it in Task Manager.
      _ref.refresh(launchAtStartupProvider.future),
    ]);

    final home = _ref.read(homeProvider);
    final devices = home.devices;
    _menuDevices = {
      for (final (index, device) in devices.indexed)
        _firstDeviceId + index: device.ip,
    };

    await _shell.showTrayMenu([
      TrayMenuItem(id: 0, label: _summary(devices), enabled: false),
      const TrayMenuSeparator(),
      if (devices.isNotEmpty) ...[
        for (final (index, device) in devices.indexed)
          TrayMenuItem(
            id: _firstDeviceId + index,
            label: device.isOnline
                ? device.nickname
                : '${device.nickname} — hors ligne',
            checked: device.isOnline && device.deviceOn,
            enabled: device.isOnline && !home.isToggling(device.ip),
          ),
        const TrayMenuSeparator(),
        TrayMenuItem(
          id: _turnOffAllId,
          label: 'Tout éteindre',
          enabled: devices.any((d) => d.isOnline && d.deviceOn),
        ),
        const TrayMenuSeparator(),
      ],
      const TrayMenuItem(id: _openId, label: 'Ouvrir Jolt'),
      TrayMenuItem(
        id: _launchAtStartupId,
        label: 'Lancer au démarrage',
        checked: _launchAtStartup,
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
        await _ref
            .read(launchAtStartupProvider.notifier)
            .setEnabled(enabled: !_launchAtStartup);
      case _quitId:
        await _shell.quit();
      default:
        final ip = _menuDevices[id];
        if (ip != null) await _toggle(ip);
    }
  }

  Future<void> _toggle(String ip) async {
    if (await _home.toggleDevice(ip)) return;

    final device = _ref.read(homeProvider).deviceAt(ip);
    await _shell.showNotification(
      title: 'Jolt',
      message: '${device?.nickname ?? ip} est injoignable',
    );
  }
}
