import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:tapo/core/klap_crypto.dart';
import 'package:tapo/core/klap_session.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/tapo_client.dart';

/// High-level service for managing Tapo devices
/// Handles session management and device communication
class TapoService {
  TapoService({required Uint8List authHash}) : _authHash = authHash;

  /// Factory constructor from email/password
  factory TapoService.fromCredentials(String email, String password) {
    return TapoService(authHash: generateAuthHash(email, password));
  }

  final Uint8List _authHash;
  final Map<String, KlapSession> _sessions = {};
  final Map<String, TapoClient> _clients = {};

  /// Connect to device, returns true on successful handshake
  Future<bool> connectToDevice(String ip) async {
    dev.log('[TapoService] Connecting to $ip');
    // Reuse existing session if established
    if (_sessions.containsKey(ip) && _sessions[ip]!.isEstablished) {
      dev.log('[TapoService] Reusing existing session for $ip');
      return true;
    }

    final session = KlapSession(deviceIp: ip, authHash: _authHash);
    final success = await session.handshake();

    if (success) {
      dev.log('[TapoService] Connected to $ip');
      _sessions[ip] = session;
      _clients[ip] = TapoClient(session: session);
    } else {
      dev.log('[TapoService] Failed to connect to $ip');
    }

    return success;
  }

  /// Get device state, returns TapoDevice or null if unreachable
  Future<TapoDevice?> getDeviceState(String ip) async {
    dev.log('[TapoService] Getting device state for $ip');
    // Ensure connected
    if (!await connectToDevice(ip)) {
      dev.log('[TapoService] Device $ip marked offline (connection failed)');
      return TapoDevice(
        ip: ip,
        nickname: 'Unknown',
        model: 'Unknown',
        deviceOn: false,
        isOnline: false,
      );
    }

    final client = _clients[ip]!;
    final info = await client.getDeviceInfo();

    if (info == null) {
      // Session may have expired, clear and return offline
      dev.log('[TapoService] Device $ip marked offline (getDeviceInfo failed)');
      _sessions.remove(ip);
      _clients.remove(ip);
      return TapoDevice(
        ip: ip,
        nickname: 'Unknown',
        model: 'Unknown',
        deviceOn: false,
        isOnline: false,
      );
    }

    dev.log('[TapoService] Device $ip online: ${info['nickname']}');
    return TapoDevice(
      ip: ip,
      nickname: info['nickname'] as String? ?? 'Tapo Device',
      model: info['model'] as String? ?? 'Unknown',
      deviceOn: info['device_on'] as bool? ?? false,
      isOnline: true,
    );
  }

  /// Toggle device on/off, returns updated state or null on failure
  Future<TapoDevice?> toggleDevice(String ip) async {
    // Get current state
    final currentState = await getDeviceState(ip);
    if (currentState == null || !currentState.isOnline) {
      return currentState;
    }

    final client = _clients[ip];
    if (client == null) return null;

    // Toggle to opposite state
    final newState = !currentState.deviceOn;
    final success = await client.setDeviceOn(on: newState);

    if (!success) {
      // Session may have expired
      _sessions.remove(ip);
      _clients.remove(ip);
      return currentState.copyWith(isOnline: false);
    }

    return currentState.copyWith(deviceOn: newState);
  }

  /// Disconnect from device (clear session)
  void disconnect(String ip) {
    _sessions.remove(ip);
    _clients.remove(ip);
  }

  /// Disconnect from all devices
  void disconnectAll() {
    _sessions.clear();
    _clients.clear();
  }
}
