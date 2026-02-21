import 'dart:typed_data';

import 'package:tapo/core/klap_crypto.dart';
import 'package:tapo/core/klap_session.dart';
import 'package:tapo/core/tpap_session.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/tapo_client.dart';
import 'package:tapo/services/tpap_client.dart';

/// High-level service for managing Tapo devices
/// Handles session management and device communication
/// Supports both KLAP (older firmware) and TPAP (firmware 1.4+)
class TapoService {
  TapoService({
    required Uint8List authHash,
    required String email,
    required String password,
  }) : _authHash = authHash,
       _email = email,
       _password = password;

  /// Factory constructor from email/password
  factory TapoService.fromCredentials(String email, String password) {
    return TapoService(
      authHash: generateAuthHash(email, password),
      email: email,
      password: password,
    );
  }

  final Uint8List _authHash;
  final String _email;
  final String _password;

  // KLAP sessions and clients (older firmware)
  final Map<String, KlapSession> _sessions = {};
  final Map<String, TapoClient> _clients = {};

  // TPAP sessions and clients (firmware 1.4+)
  final Map<String, TpapSession> _tpapSessions = {};
  final Map<String, TpapClient> _tpapClients = {};

  // Track which devices need TPAP
  final Set<String> _tpapDevices = {};

  TapoDevice _offlineDevice(String ip) => TapoDevice(
    ip: ip,
    nickname: 'Unknown',
    model: 'Unknown',
    deviceOn: false,
    isOnline: false,
  );

  /// Connect to device, returns true on successful handshake
  /// Tries KLAP first, falls back to TPAP if device requires it
  Future<bool> connectToDevice(String ip) async {
    // Reuse existing session if established
    if (_sessions.containsKey(ip) && _sessions[ip]!.isEstablished) {
      return true;
    }

    // If device is known to require TPAP, skip KLAP
    if (_tpapDevices.contains(ip)) {
      return _connectTpap(ip);
    }

    // Try KLAP first
    final session = KlapSession(deviceIp: ip, authHash: _authHash);
    final success = await session.handshake();

    if (success) {
      _sessions[ip] = session;
      _clients[ip] = TapoClient(session: session);
      return true;
    }

    // KLAP failed - try TPAP (firmware 1.4+)
    _tpapDevices.add(ip);
    return _connectTpap(ip);
  }

  /// Connect via TPAP protocol
  Future<bool> _connectTpap(String ip) async {
    // Check for existing TPAP session
    if (_tpapSessions.containsKey(ip) && _tpapSessions[ip]!.isEstablished) {
      return true;
    }

    final tpapSession = TpapSession(
      deviceIp: ip,
      credentials: TpapCredentials(email: _email, password: _password),
    );

    // Probe to understand what the device supports
    await tpapSession.probeDevice();

    // Try TPAP handshake
    final success = await tpapSession.handshake();
    if (success) {
      _tpapSessions[ip] = tpapSession;
      _tpapClients[ip] = TpapClient(session: tpapSession);
      return true;
    }

    await tpapSession.close();
    return false;
  }

  /// Get client for device (TPAP or KLAP), null if not connected
  _DeviceClient? _getClient(String ip) {
    if (_tpapDevices.contains(ip) && _tpapClients.containsKey(ip)) {
      final client = _tpapClients[ip]!;
      return (getInfo: client.getDeviceInfo, setOn: client.setDeviceOn);
    }
    if (_clients.containsKey(ip)) {
      final client = _clients[ip]!;
      return (getInfo: client.getDeviceInfo, setOn: client.setDeviceOn);
    }
    return null;
  }

  /// Get device state, returns TapoDevice (offline if unreachable)
  Future<TapoDevice> getDeviceState(String ip) async {
    if (!await connectToDevice(ip)) {
      return _offlineDevice(ip);
    }

    final client = _getClient(ip);
    final info = await client?.getInfo();

    if (info == null) {
      disconnect(ip);
      return _offlineDevice(ip);
    }

    return TapoDevice(
      ip: ip,
      nickname: info['nickname'] as String? ?? 'Tapo Device',
      model: info['model'] as String? ?? 'Unknown',
      deviceOn: info['device_on'] as bool? ?? false,
      isOnline: true,
    );
  }

  /// Toggle device on/off, returns updated state
  Future<TapoDevice> toggleDevice(String ip) async {
    final currentState = await getDeviceState(ip);
    if (!currentState.isOnline) return currentState;

    final client = _getClient(ip);
    if (client == null) return currentState;

    final newState = !currentState.deviceOn;
    final success = await client.setOn(on: newState);

    if (!success) {
      disconnect(ip);
      return currentState.copyWith(isOnline: false);
    }

    return currentState.copyWith(deviceOn: newState);
  }

  /// Disconnect from device (clear session)
  void disconnect(String ip) {
    // Clean up KLAP
    _sessions.remove(ip);
    _clients.remove(ip);

    // Clean up TPAP
    _tpapSessions[ip]?.close();
    _tpapSessions.remove(ip);
    _tpapClients.remove(ip);
  }

  /// Disconnect from all devices
  void disconnectAll() {
    // Clean up KLAP
    _sessions.clear();
    _clients.clear();

    // Clean up TPAP
    for (final session in _tpapSessions.values) {
      session.close();
    }
    _tpapSessions.clear();
    _tpapClients.clear();
  }
}

/// Client interface for device operations
typedef _DeviceClient = ({
  Future<Map<String, dynamic>?> Function() getInfo,
  Future<bool> Function({required bool on}) setOn,
});
