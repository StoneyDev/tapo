import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/core/di.dart';
import 'package:tapo/services/secure_storage_service.dart';

class ConfigViewModel extends ChangeNotifier {
  ConfigViewModel({SecureStorageService? storageService})
    : _storageService =
          storageService ?? GetIt.instance<SecureStorageService>();

  final SecureStorageService _storageService;

  List<String> _deviceIps = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get deviceIps => List.unmodifiable(_deviceIps);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<({String email, String password})> loadConfig() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final creds = await _storageService.getCredentials();
      _deviceIps = await _storageService.getDeviceIps();
      return (email: creds.email ?? '', password: creds.password ?? '');
    } on Exception {
      _errorMessage = 'Failed to load configuration';
      return (email: '', password: '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  /// Validate IPv4 address format
  bool _isValidIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  Future<bool> saveConfig(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _setError('Email and password required');
      return false;
    }
    if (!_isValidEmail(email)) {
      _setError('Invalid email format');
      return false;
    }
    if (password.length < 8) {
      _setError('Password must be at least 8 characters');
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _storageService.saveCredentials(email, password);
      await _storageService.saveDeviceIps(_deviceIps);
      registerTapoService(email, password);
      return true;
    } on Exception {
      _setError('Failed to save configuration');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addDeviceIp(String ip) {
    final trimmedIp = ip.trim();

    if (trimmedIp.isEmpty) {
      _setError('IP address cannot be empty');
    } else if (!_isValidIpv4(trimmedIp)) {
      _setError('Invalid IP address format');
    } else if (_deviceIps.contains(trimmedIp)) {
      _setError('IP address already added');
    } else {
      _errorMessage = null;
      _deviceIps.add(trimmedIp);
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void removeDeviceIp(String ip) {
    _deviceIps.remove(ip);
    notifyListeners();
  }
}
