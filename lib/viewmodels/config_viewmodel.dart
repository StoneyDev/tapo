import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../services/secure_storage_service.dart';
import '../core/di.dart';

class ConfigViewModel extends ChangeNotifier {
  final SecureStorageService _storageService;

  String _email = '';
  String _password = '';
  List<String> _deviceIps = [];
  bool _isLoading = false;
  String? _errorMessage;

  ConfigViewModel({SecureStorageService? storageService})
      : _storageService = storageService ?? GetIt.instance<SecureStorageService>();

  // Getters
  String get email => _email;
  String get password => _password;
  List<String> get deviceIps => List.unmodifiable(_deviceIps);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Setters for form fields
  set email(String value) {
    _email = value;
    notifyListeners();
  }

  set password(String value) {
    _password = value;
    notifyListeners();
  }

  Future<void> loadConfig() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final creds = await _storageService.getCredentials();
      _email = creds.email ?? '';
      _password = creds.password ?? '';
      _deviceIps = await _storageService.getDeviceIps();
    } catch (e) {
      _errorMessage = 'Failed to load config: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveConfig() async {
    if (_email.isEmpty || _password.isEmpty) {
      _errorMessage = 'Email and password required';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _storageService.saveCredentials(_email, _password);
      await _storageService.saveDeviceIps(_deviceIps);
      // Register TapoService with credentials
      registerTapoService(_email, _password);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save config: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addDeviceIp(String ip) {
    if (ip.isNotEmpty && !_deviceIps.contains(ip)) {
      _deviceIps.add(ip);
      notifyListeners();
    }
  }

  void removeDeviceIp(String ip) {
    _deviceIps.remove(ip);
    notifyListeners();
  }
}
