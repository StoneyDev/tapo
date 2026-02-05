import 'package:flutter/foundation.dart';
import 'package:tapo/core/di.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';

class HomeViewModel extends ChangeNotifier {
  final SecureStorageService _storageService = getIt<SecureStorageService>();
  final WidgetDataService _widgetDataService = getIt<WidgetDataService>();

  List<TapoDevice> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _togglingDevices = {};
  final Map<String, DateTime> _lastToggleTime = {};
  static const _toggleCooldown = Duration(milliseconds: 500);
  DateTime? _lastLoadTime;
  static const _loadCooldown = Duration(seconds: 2);

  List<TapoDevice> get devices => List.unmodifiable(_devices);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Check if a specific device is currently being toggled
  bool isToggling(String ip) => _togglingDevices.contains(ip);

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
      await _widgetDataService.saveAllDevices(_devices);
    } on Exception {
      _errorMessage = 'Failed to load devices';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove device from configuration
  Future<void> removeDevice(String ip) async {
    _devices = _devices.where((d) => d.ip != ip).toList();
    notifyListeners();

    final ips = await _storageService.getDeviceIps();
    ips.remove(ip);
    await _storageService.saveDeviceIps(ips);
    await _widgetDataService.saveAllDevices(_devices);

    if (getIt.isRegistered<TapoService>()) {
      getIt<TapoService>().disconnect(ip);
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

    _togglingDevices.add(ip);
    notifyListeners();

    try {
      final updatedDevice = await getIt<TapoService>().toggleDevice(ip);
      _devices = List.from(_devices)..[index] = updatedDevice;
      _errorMessage = null;

      await _widgetDataService.saveDeviceState(
        ip: updatedDevice.ip,
        model: updatedDevice.model,
        deviceOn: updatedDevice.deviceOn,
        isOnline: updatedDevice.isOnline,
      );
    } on Exception {
      _errorMessage = 'Failed to toggle device';
    } finally {
      _togglingDevices.remove(ip);
      notifyListeners();
    }
  }
}
