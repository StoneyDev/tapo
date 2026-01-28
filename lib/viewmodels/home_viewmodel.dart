import 'package:flutter/foundation.dart';
import 'package:tapo/core/di.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';

class HomeViewModel extends ChangeNotifier {
  final SecureStorageService _storageService = getIt<SecureStorageService>();

  List<TapoDevice> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _togglingDevices = {};
  final Map<String, DateTime> _lastToggleTime = {};
  static const _toggleCooldown = Duration(milliseconds: 500);

  List<TapoDevice> get devices => List.unmodifiable(_devices);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Check if a specific device is currently being toggled
  bool isToggling(String ip) => _togglingDevices.contains(ip);

  /// Refresh devices (alias for loadDevices)
  Future<void> refresh() => loadDevices();

  /// Load all configured devices and fetch their states
  Future<void> loadDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get configured device IPs
      final ips = await _storageService.getDeviceIps();
      if (ips.isEmpty) {
        _devices = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Check if TapoService is registered
      if (!getIt.isRegistered<TapoService>()) {
        _errorMessage = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final tapoService = getIt<TapoService>();

      // Fetch state for all devices in parallel
      final futures = ips.map(tapoService.getDeviceState);
      final results = await Future.wait(futures);
      _devices = results.whereType<TapoDevice>().toList();
      _errorMessage = null;
    } on Exception {
      _errorMessage = 'Failed to load devices';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove device from configuration
  Future<void> removeDevice(String ip) async {
    // Remove from local list
    _devices = _devices.where((d) => d.ip != ip).toList();
    notifyListeners();

    // Remove from storage
    final ips = await _storageService.getDeviceIps();
    ips.remove(ip);
    await _storageService.saveDeviceIps(ips);

    // Disconnect session if exists
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

    // Rate limiting - prevent rapid toggles
    final lastToggle = _lastToggleTime[ip];
    if (lastToggle != null &&
        DateTime.now().difference(lastToggle) < _toggleCooldown) {
      return; // Ignore rapid toggle requests
    }
    _lastToggleTime[ip] = DateTime.now();

    // Find device index
    final index = _devices.indexWhere((d) => d.ip == ip);
    if (index == -1) return;

    // Mark as toggling
    _togglingDevices.add(ip);
    notifyListeners();

    try {
      final tapoService = getIt<TapoService>();
      final updatedDevice = await tapoService.toggleDevice(ip);

      if (updatedDevice != null) {
        _devices = List.from(_devices);
        _devices[index] = updatedDevice;
      }
    } finally {
      _togglingDevices.remove(ip);
      notifyListeners();
    }
  }
}
