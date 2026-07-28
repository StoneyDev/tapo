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
  static const _toggleCooldown = Duration(milliseconds: 500);
  DateTime? _lastLoadTime;
  static const _loadCooldown = Duration(seconds: 2);

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

  /// Refresh devices with cooldown to avoid redundant network calls
  Future<void> refresh() {
    final now = DateTime.now();
    if (_lastLoadTime != null &&
        now.difference(_lastLoadTime!) < _loadCooldown) {
      return Future.value();
    }
    return loadDevices();
  }

  /// Load all configured devices and fetch their states
  Future<void> loadDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ips = await _storageService.getDeviceIps();
      if (ips.isEmpty) {
        cancelAllPowerOffs();
        _devices = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (!getIt.isRegistered<TapoService>()) {
        _errorMessage = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final tapoService = getIt<TapoService>();
      _devices = await Future.wait(ips.map(tapoService.getDeviceState));
      _lastLoadTime = DateTime.now();

      // Widget sync is best-effort; don't mask a successful load
      try {
        await _widgetDataService.saveAllDevices(_devices);
        await _widgetDataService.refreshWidgets();
      } on Exception {
        // Non-critical: devices loaded but widget state may be stale
      }
    } on Exception {
      _errorMessage = 'Failed to load devices';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  /// Toggle device on/off state
  Future<void> toggleDevice(String ip) async {
    if (!getIt.isRegistered<TapoService>()) {
      _errorMessage = 'Not authenticated';
      notifyListeners();
      return;
    }

    final lastToggle = _lastToggleTime[ip];
    if (lastToggle != null &&
        DateTime.now().difference(lastToggle) < _toggleCooldown) {
      return;
    }
    _lastToggleTime[ip] = DateTime.now();

    final index = _devices.indexWhere((d) => d.ip == ip);
    if (index == -1) return;

    cancelPowerOff(ip);
    await _updateDevice(
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

  Future<void> _updateDevice(
    String ip,
    Future<TapoDevice> Function(TapoService service) action, {
    required String failureMessage,
  }) async {
    final index = _devices.indexWhere((device) => device.ip == ip);
    if (index == -1 || _togglingDevices.contains(ip)) return;

    _togglingDevices.add(ip);
    notifyListeners();

    try {
      final updatedDevice = await action(getIt<TapoService>());
      _devices = List.from(_devices)..[index] = updatedDevice;
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
    } on Exception {
      _errorMessage = failureMessage;
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
