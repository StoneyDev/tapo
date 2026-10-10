import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tapo/core/di.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    Duration powerOffDelay = const Duration(minutes: 1),
    Duration countdownTick = const Duration(seconds: 1),
  }) : _powerOffDelay = powerOffDelay,
       _countdownTick = countdownTick;

  final SecureStorageService _storageService = getIt<SecureStorageService>();
  final WidgetDataService _widgetDataService = getIt<WidgetDataService>();
  final Duration _powerOffDelay;
  final Duration _countdownTick;

  List<TapoDevice> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _togglingDevices = {};
  final Map<String, DateTime> _lastToggleTime = {};
  final Map<String, DateTime> _powerOffDeadlines = {};
  final Map<String, Timer> _powerOffTimers = {};
  Future<void>? _inFlightLoad;
  DateTime? _lastLoadedAt;

  /// Only the latest load may publish its results.
  int _loadGeneration = 0;

  /// Plugs toggled or removed while a load runs keep their newer state:
  /// [_lastChange] holds, per IP, the value of [_changeCount] at its last
  /// change.
  int _changeCount = 0;
  final Map<String, int> _lastChange = {};
  static const _toggleCooldown = Duration(milliseconds: 500);

  List<TapoDevice> get devices => List.unmodifiable(_devices);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Check if a specific device is currently being toggled
  bool isToggling(String ip) => _togglingDevices.contains(ip);

  Duration? powerOffRemaining(String ip) {
    final deadline = _powerOffDeadlines[ip];
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void schedulePowerOff(String ip) {
    final device = _devices.where((device) => device.ip == ip).firstOrNull;
    if (device == null ||
        !device.isOnline ||
        !device.deviceOn ||
        isToggling(ip)) {
      return;
    }

    cancelPowerOff(ip, notify: false);
    _powerOffDeadlines[ip] = DateTime.now().add(_powerOffDelay);
    _powerOffTimers[ip] = Timer.periodic(_countdownTick, (_) {
      if (powerOffRemaining(ip) != Duration.zero) {
        notifyListeners();
        return;
      }

      cancelPowerOff(ip);
      unawaited(_turnOffDevice(ip));
    });
    notifyListeners();
  }

  void cancelPowerOff(String ip, {bool notify = true}) {
    final hadDeadline = _powerOffDeadlines.remove(ip) != null;
    final timer = _powerOffTimers.remove(ip);
    timer?.cancel();
    if ((hadDeadline || timer != null) && notify) notifyListeners();
  }

  void cancelAllPowerOffs() {
    if (_powerOffDeadlines.isEmpty) return;
    for (final timer in _powerOffTimers.values) {
      timer.cancel();
    }
    _powerOffDeadlines.clear();
    _powerOffTimers.clear();
    notifyListeners();
  }

  /// Retry immediately so a restored Wi-Fi connection can be used.
  ///
  /// A [silent] refresh (tray menu, window focus) keeps the current devices
  /// on screen without a spinner, keeps them when it fails, and joins a load
  /// that is already running.
  Future<void> refresh({bool silent = false}) {
    final running = _inFlightLoad;
    if (silent && running != null) return running;
    return loadDevices(silent: silent);
  }

  /// Silently refresh unless devices were loaded less than [maxAge] ago.
  Future<void> refreshIfStale(Duration maxAge) {
    final lastLoadedAt = _lastLoadedAt;
    if (lastLoadedAt != null &&
        DateTime.now().difference(lastLoadedAt) < maxAge) {
      return Future.value();
    }
    return refresh(silent: true);
  }

  /// Load all configured devices and fetch their states
  Future<void> loadDevices({bool silent = false}) {
    final load = _loadDevices(silent: silent, generation: ++_loadGeneration);
    _inFlightLoad = load;
    return load.whenComplete(() {
      if (identical(_inFlightLoad, load)) _inFlightLoad = null;
    });
  }

  Future<void> _loadDevices({
    required bool silent,
    required int generation,
  }) async {
    bool isLatest() => generation == _loadGeneration;

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    final changesAtStart = _changeCount;

    try {
      final ips = await _storageService.getDeviceIps();
      if (!isLatest()) return;
      if (ips.isEmpty) {
        cancelAllPowerOffs();
        _devices = [];
        _errorMessage = null;
        _lastLoadedAt = DateTime.now();
        return;
      }

      if (!getIt.isRegistered<TapoService>()) {
        if (!silent) _errorMessage = 'Not authenticated';
        return;
      }

      final tapoService = getIt<TapoService>();
      final fetched = await Future.wait(ips.map(tapoService.getDeviceState));
      if (!isLatest()) return;
      _devices = [
        for (final device in fetched)
          if ((_lastChange[device.ip] ?? 0) <= changesAtStart)
            device
          else
            // Changed meanwhile: keep the newer state, or drop it if removed.
            ?_deviceAt(device.ip),
      ];
      _errorMessage = null;
      _lastLoadedAt = DateTime.now();

      // Widget sync is best-effort; don't mask a successful load
      try {
        await _widgetDataService.saveAllDevices(_devices);
        await _widgetDataService.refreshWidgets();
      } on Exception {
        // Non-critical: devices loaded but widget state may be stale
      }
    } on Exception {
      if (!silent && isLatest()) _errorMessage = 'Failed to load devices';
    } finally {
      if (isLatest()) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  TapoDevice? _deviceAt(String ip) =>
      _devices.where((device) => device.ip == ip).firstOrNull;

  void _markChanged(String ip) => _lastChange[ip] = ++_changeCount;

  /// Turn off every online device that is on, cancelling any countdown.
  Future<void> turnOffAll() async {
    cancelAllPowerOffs();
    final ips = [
      for (final device in _devices)
        if (device.isOnline && device.deviceOn) device.ip,
    ];
    await Future.wait(ips.map(_turnOffDevice));
  }

  /// Update a device's IP address
  Future<void> updateDeviceIp(String oldIp, String newIp) async {
    final ips = await _storageService.getDeviceIps();
    final index = ips.indexOf(oldIp);
    if (index == -1) return;
    if (ips.contains(newIp)) {
      _errorMessage = 'IP address already exists';
      notifyListeners();
      return;
    }

    ips[index] = newIp;
    cancelPowerOff(oldIp);
    await _storageService.saveDeviceIps(ips);

    if (getIt.isRegistered<TapoService>()) {
      await getIt<TapoService>().disconnect(oldIp);
    }

    await loadDevices();
  }

  /// Remove device from configuration
  Future<void> removeDevice(String ip) async {
    cancelPowerOff(ip);
    _devices = _devices.where((d) => d.ip != ip).toList();
    _markChanged(ip);
    notifyListeners();

    final ips = await _storageService.getDeviceIps();
    ips.remove(ip);
    await _storageService.saveDeviceIps(ips);
    await _widgetDataService.saveAllDevices(_devices);
    await _widgetDataService.refreshWidgets();

    if (getIt.isRegistered<TapoService>()) {
      await getIt<TapoService>().disconnect(ip);
    }
  }

  /// Toggle device on/off state.
  ///
  /// Returns false when the plug could not be reached. A toggle skipped
  /// because one is already running, or by the double-click cooldown, is not
  /// a failure.
  Future<bool> toggleDevice(String ip) async {
    if (!getIt.isRegistered<TapoService>()) {
      _errorMessage = 'Not authenticated';
      notifyListeners();
      return false;
    }

    final lastToggle = _lastToggleTime[ip];
    if (lastToggle != null &&
        DateTime.now().difference(lastToggle) < _toggleCooldown) {
      return true;
    }
    _lastToggleTime[ip] = DateTime.now();

    if (_deviceAt(ip) == null) return true;

    cancelPowerOff(ip);
    return await _updateDevice(
      ip,
      (service) => service.toggleDevice(ip),
      failureMessage: 'Failed to toggle device',
    );
  }

  Future<void> _turnOffDevice(String ip) async {
    final device = _devices.where((device) => device.ip == ip).firstOrNull;
    if (device == null || !device.isOnline || !device.deviceOn) return;
    if (!getIt.isRegistered<TapoService>()) {
      _errorMessage = 'Not authenticated';
      notifyListeners();
      return;
    }

    await _updateDevice(
      ip,
      (service) => service.setDevicePower(ip, on: false),
      failureMessage: 'Failed to turn off device',
    );
  }

  /// Returns false when the plug could not be reached.
  Future<bool> _updateDevice(
    String ip,
    Future<TapoDevice> Function(TapoService service) action, {
    required String failureMessage,
  }) async {
    if (_deviceAt(ip) == null || _togglingDevices.contains(ip)) return true;

    _togglingDevices.add(ip);
    notifyListeners();

    try {
      final updatedDevice = await action(getIt<TapoService>());
      // The list may have changed (reload, removal) while waiting.
      final index = _devices.indexWhere((device) => device.ip == ip);
      if (index != -1) {
        _devices = List.of(_devices)..[index] = updatedDevice;
        _markChanged(ip);
      }
      _errorMessage = null;

      // Widget sync is best-effort; don't mask a successful toggle
      try {
        await _widgetDataService.saveDeviceState(
          ip: updatedDevice.ip,
          model: updatedDevice.model,
          nickname: updatedDevice.nickname,
          deviceOn: updatedDevice.deviceOn,
          isOnline: updatedDevice.isOnline,
        );
        await _widgetDataService.refreshWidgets();
      } on Exception {
        // Non-critical: device was toggled but widget state may be stale
      }
      return updatedDevice.isOnline;
    } on Exception {
      _errorMessage = failureMessage;
      return false;
    } finally {
      _togglingDevices.remove(ip);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final timer in _powerOffTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
