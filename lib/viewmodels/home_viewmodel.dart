import 'package:flutter/foundation.dart';
import '../core/di.dart';
import '../models/tapo_device.dart';
import '../services/secure_storage_service.dart';
import '../services/tapo_service.dart';

class HomeViewModel extends ChangeNotifier {
  List<TapoDevice> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _togglingDevices = {};

  List<TapoDevice> get devices => List.unmodifiable(_devices);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Check if a specific device is currently being toggled
  bool isToggling(String ip) => _togglingDevices.contains(ip);

  final SecureStorageService _storageService = getIt<SecureStorageService>();

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

      // Fetch state for each device
      final List<TapoDevice> fetchedDevices = [];
      for (final ip in ips) {
        final device = await tapoService.getDeviceState(ip);
        if (device != null) {
          fetchedDevices.add(device);
        }
      }

      _devices = fetchedDevices;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load devices: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle device on/off state
  Future<void> toggleDevice(String ip) async {
    if (!getIt.isRegistered<TapoService>()) {
      _errorMessage = 'Not authenticated';
      notifyListeners();
      return;
    }

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

  /// Refresh all device states
  Future<void> refresh() async {
    await loadDevices();
  }
}
