import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/providers/services.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';

part 'home_provider.freezed.dart';

@freezed
abstract class HomeState with _$HomeState {
  const factory HomeState({
    @Default([]) List<TapoDevice> devices,
    @Default(false) bool isLoading,
    String? errorMessage,

    /// Plugs with a command in flight.
    @Default(<String>{}) Set<String> toggling,

    /// Time left before each scheduled plug turns off.
    @Default(<String, Duration>{}) Map<String, Duration> powerOffRemaining,
  }) = _HomeState;

  const HomeState._();

  TapoDevice? deviceAt(String ip) =>
      devices.where((device) => device.ip == ip).firstOrNull;

  bool isToggling(String ip) => toggling.contains(ip);
}

/// The plugs of the signed-in account, shared by the window and the tray so
/// they always agree.
final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

typedef PlugList = ({
  bool isLoading,
  String? errorMessage,
  List<TapoDevice> devices,
});

/// The plug list without the countdowns: a tick only rebuilds its plug.
final plugListProvider = Provider<PlugList>((ref) {
  final home = ref.watch(homeProvider);
  return (
    isLoading: home.isLoading,
    errorMessage: home.errorMessage,
    devices: home.devices,
  );
});

typedef Plug = ({
  TapoDevice device,
  bool isToggling,
  Duration? powerOffRemaining,
});

/// One plug and its pending actions; null once removed.
final ProviderFamily<Plug?, String> plugProvider = Provider.autoDispose
    .family<Plug?, String>((ref, ip) {
      final home = ref.watch(homeProvider);
      final device = home.deviceAt(ip);
      if (device == null) return null;
      return (
        device: device,
        isToggling: home.isToggling(ip),
        powerOffRemaining: home.powerOffRemaining[ip],
      );
    });

class HomeNotifier extends Notifier<HomeState> {
  HomeNotifier({
    this._powerOffDelay = const Duration(minutes: 1),
    this._countdownTick = const Duration(seconds: 1),
  });

  final Duration _powerOffDelay;
  final Duration _countdownTick;

  final Map<String, DateTime> _lastToggleTime = {};
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

  SecureStorageService get _storage => ref.read(secureStorageProvider);
  WidgetDataService get _widgetData => ref.read(widgetDataProvider);

  /// The signed-in account's service; reading it applies a pending sign-out
  /// or sign-in.
  TapoService? get _service => ref.read(tapoServiceProvider);

  @override
  HomeState build() {
    final service = ref.watch(tapoServiceProvider);
    ref.onDispose(_stopCountdowns);
    _lastToggleTime.clear();
    _lastLoadedAt = null;
    _inFlightLoad = null;
    if (service == null) return const HomeState();

    // State cannot change during build: the first load starts right after.
    _inFlightLoad = Future.microtask(() async {
      if (_isCurrent(service)) await loadDevices();
    });
    return const HomeState(isLoading: true);
  }

  /// Whether work started with [service] may still publish its results: the
  /// account has not changed meanwhile.
  bool _isCurrent(TapoService? service) =>
      ref.mounted && identical(_service, service);

  void schedulePowerOff(String ip) {
    final device = state.deviceAt(ip);
    if (device == null ||
        !device.isOnline ||
        !device.deviceOn ||
        state.isToggling(ip)) {
      return;
    }

    final service = _service;
    final deadline = DateTime.now().add(_powerOffDelay);
    _powerOffTimers.remove(ip)?.cancel();
    _powerOffTimers[ip] = Timer.periodic(_countdownTick, (_) {
      if (!_isCurrent(service)) return;
      final remaining = deadline.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _setPowerOffRemaining(ip, remaining);
        return;
      }

      cancelPowerOff(ip);
      unawaited(_turnOffDevice(ip));
    });
    _setPowerOffRemaining(ip, _powerOffDelay);
  }

  void _setPowerOffRemaining(String ip, Duration remaining) {
    state = state.copyWith(
      powerOffRemaining: {...state.powerOffRemaining, ip: remaining},
    );
  }

  void cancelPowerOff(String ip) {
    _powerOffTimers.remove(ip)?.cancel();
    if (!state.powerOffRemaining.containsKey(ip)) return;
    state = state.copyWith(
      powerOffRemaining: Map.of(state.powerOffRemaining)..remove(ip),
    );
  }

  void _cancelAllPowerOffs() {
    _stopCountdowns();
    if (state.powerOffRemaining.isEmpty) return;
    state = state.copyWith(powerOffRemaining: const {});
  }

  void _stopCountdowns() {
    for (final timer in _powerOffTimers.values) {
      timer.cancel();
    }
    _powerOffTimers.clear();
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
    final service = _service;
    final storage = _storage;
    final widgetData = _widgetData;
    bool isLatest() => _isCurrent(service) && generation == _loadGeneration;

    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }
    final changesAtStart = _changeCount;

    try {
      final ips = await storage.getDeviceIps();
      if (!isLatest()) return;
      if (ips.isEmpty) {
        _cancelAllPowerOffs();
        state = state.copyWith(
          devices: const [],
          isLoading: false,
          errorMessage: null,
        );
        _lastLoadedAt = DateTime.now();
        return;
      }

      if (service == null) {
        if (!silent) state = state.copyWith(errorMessage: 'Not authenticated');
        return;
      }

      final fetched = await Future.wait(ips.map(service.getDeviceState));
      if (!isLatest()) return;
      final devices = [
        for (final device in fetched)
          if ((_lastChange[device.ip] ?? 0) <= changesAtStart)
            device
          else
            // Changed meanwhile: keep the newer state, or drop it if removed.
            ?state.deviceAt(device.ip),
      ];
      state = state.copyWith(
        devices: devices,
        isLoading: false,
        errorMessage: null,
      );
      _lastLoadedAt = DateTime.now();

      // Widget sync is best-effort; don't mask a successful load
      try {
        await widgetData.saveAllDevices(devices);
        await widgetData.refreshWidgets();
      } on Exception {
        // Non-critical: devices loaded but widget state may be stale
      }
    } on Exception {
      if (!silent && isLatest()) {
        state = state.copyWith(errorMessage: 'Failed to load devices');
      }
    } finally {
      if (isLatest()) state = state.copyWith(isLoading: false);
    }
  }

  void _markChanged(String ip) => _lastChange[ip] = ++_changeCount;

  /// Turn off every online device that is on, cancelling any countdown.
  Future<void> turnOffAll() async {
    _cancelAllPowerOffs();
    final ips = [
      for (final device in state.devices)
        if (device.isOnline && device.deviceOn) device.ip,
    ];
    await Future.wait(ips.map(_turnOffDevice));
  }

  /// Update a device's IP address
  Future<void> updateDeviceIp(String oldIp, String newIp) async {
    final service = _service;
    final storage = _storage;
    final ips = await storage.getDeviceIps();
    if (!_isCurrent(service)) return;
    final index = ips.indexOf(oldIp);
    if (index == -1) return;
    if (ips.contains(newIp)) {
      state = state.copyWith(errorMessage: 'IP address already exists');
      return;
    }

    ips[index] = newIp;
    cancelPowerOff(oldIp);
    await storage.saveDeviceIps(ips);
    if (!_isCurrent(service)) return;
    await service?.disconnect(oldIp);

    await loadDevices();
  }

  /// Remove device from configuration
  Future<void> removeDevice(String ip) async {
    final service = _service;
    cancelPowerOff(ip);
    state = state.copyWith(
      devices: [
        for (final device in state.devices)
          if (device.ip != ip) device,
      ],
    );
    _markChanged(ip);

    final storage = _storage;
    final ips = await storage.getDeviceIps();
    if (!_isCurrent(service)) return;
    ips.remove(ip);
    await storage.saveDeviceIps(ips);
    if (!_isCurrent(service)) return;
    final widgetData = _widgetData;
    await widgetData.saveAllDevices(state.devices);
    await widgetData.refreshWidgets();

    await service?.disconnect(ip);
  }

  /// Toggle device on/off state.
  ///
  /// Returns false when the plug could not be reached. A toggle skipped
  /// because one is already running, or by the double-click cooldown, is not
  /// a failure.
  Future<bool> toggleDevice(String ip) async {
    final tapoService = _service;
    if (tapoService == null) {
      state = state.copyWith(errorMessage: 'Not authenticated');
      return false;
    }

    final lastToggle = _lastToggleTime[ip];
    if (lastToggle != null &&
        DateTime.now().difference(lastToggle) < _toggleCooldown) {
      return true;
    }
    _lastToggleTime[ip] = DateTime.now();

    if (state.deviceAt(ip) == null) return true;

    cancelPowerOff(ip);
    return await _updateDevice(
      ip,
      tapoService,
      () => tapoService.toggleDevice(ip),
      failureMessage: 'Failed to toggle device',
    );
  }

  Future<void> _turnOffDevice(String ip) async {
    // Signed out, the state has no plugs left.
    final device = state.deviceAt(ip);
    final tapoService = _service;
    if (device == null ||
        !device.isOnline ||
        !device.deviceOn ||
        tapoService == null) {
      return;
    }

    await _updateDevice(
      ip,
      tapoService,
      () => tapoService.setDevicePower(ip, on: false),
      failureMessage: 'Failed to turn off device',
    );
  }

  /// Returns false when the plug could not be reached.
  Future<bool> _updateDevice(
    String ip,
    TapoService service,
    Future<TapoDevice> Function() action, {
    required String failureMessage,
  }) async {
    if (state.deviceAt(ip) == null || state.isToggling(ip)) return true;

    final widgetData = _widgetData;
    state = state.copyWith(toggling: {...state.toggling, ip});

    try {
      final updatedDevice = await action();
      if (!_isCurrent(service)) return updatedDevice.isOnline;
      // The list may have changed (reload, removal) while waiting.
      var devices = state.devices;
      final index = devices.indexWhere((device) => device.ip == ip);
      if (index != -1) {
        devices = List.of(devices)..[index] = updatedDevice;
        _markChanged(ip);
      }
      state = state.copyWith(
        devices: devices,
        errorMessage: null,
        toggling: Set.of(state.toggling)..remove(ip),
      );

      // Widget sync is best-effort; don't mask a successful toggle
      try {
        await widgetData.saveDeviceState(
          ip: updatedDevice.ip,
          model: updatedDevice.model,
          nickname: updatedDevice.nickname,
          deviceOn: updatedDevice.deviceOn,
          isOnline: updatedDevice.isOnline,
        );
        await widgetData.refreshWidgets();
      } on Exception {
        // Non-critical: device was toggled but widget state may be stale
      }
      return updatedDevice.isOnline;
    } on Exception {
      if (_isCurrent(service)) {
        state = state.copyWith(errorMessage: failureMessage);
      }
      return false;
    } finally {
      // Already done on success.
      if (_isCurrent(service)) {
        state = state.copyWith(toggling: Set.of(state.toggling)..remove(ip));
      }
    }
  }
}
