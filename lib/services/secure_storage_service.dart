import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _keyEmail = 'tapo_email';
  static const _keyPassword = 'tapo_password';
  static const _keyDeviceIps = 'tapo_device_ips';

  // Credentials methods
  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<({String? email, String? password})> getCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    return (email: email, password: password);
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }

  Future<bool> hasCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    return email != null && password != null;
  }

  // Device IPs methods
  Future<void> saveDeviceIps(List<String> ips) async {
    final json = jsonEncode(ips);
    await _storage.write(key: _keyDeviceIps, value: json);
  }

  Future<List<String>> getDeviceIps() async {
    final json = await _storage.read(key: _keyDeviceIps);
    if (json == null) return [];
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.cast<String>();
  }

  Future<void> clearDeviceIps() async {
    await _storage.delete(key: _keyDeviceIps);
  }
}
