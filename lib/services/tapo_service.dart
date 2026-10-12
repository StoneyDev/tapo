import 'dart:async';
import 'dart:typed_data';

import 'package:tapo/core/http_utils.dart';
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

  /// Logged-in sessions, one per plug.
  final Map<String, _Connection> _connections = {};

  /// The last command queued for each plug. Commands to a plug run one at a
  /// time: it keeps a single session, which concurrent logins would drop, and
  /// TPAP numbers each request and its reply in sequence.
  final Map<String, Future<void>> _queues = {};

  /// Bumped by [disconnect]: work started before must not log in to the plug
  /// again.
  final Map<String, int> _generations = {};

  // Track which devices need TPAP
  final Set<String> _tpapDevices = {};

  int _generation(String ip) => _generations[ip] ?? 0;

  TapoDevice _offlineDevice(String ip) => TapoDevice(
    ip: ip,
    nickname: 'Unknown',
    model: 'Unknown',
    deviceOn: false,
    isOnline: false,
  );

  /// Connect to device, returns true on successful handshake
  /// Tries KLAP first, falls back to TPAP if device requires it
  Future<bool> connectToDevice(String ip) {
    final generation = _generation(ip);
    return _queued(ip, () async => await _connect(ip, generation) != null);
  }

  /// Runs [action] once every command queued before for [ip] has finished.
  Future<T> _queued<T>(String ip, Future<T> Function() action) async {
    final previous = _queues[ip];
    final done = Completer<void>();
    _queues[ip] = done.future;
    try {
      await previous;
      return await action();
    } finally {
      done.complete();
      if (identical(_queues[ip], done.future)) unawaited(_queues.remove(ip));
    }
  }

  /// The plug's session, logging in if needed; null if the plug cannot be
  /// reached or was disconnected since [generation]. Runs queued.
  Future<_Connection?> _connect(String ip, int generation) async {
    if (_generation(ip) != generation) return null;
    final existing = _connections[ip];
    if (existing != null) return existing;

    final connection = await _handshake(ip);
    if (_generation(ip) != generation) {
      await connection?.close();
      return null;
    }
    if (connection != null) _connections[ip] = connection;
    return connection;
  }

  /// Logs in with KLAP, or with TPAP when the plug requires it.
  Future<_Connection?> _handshake(String ip) async {
    if (!_tpapDevices.contains(ip)) {
      final session = KlapSession(deviceIp: ip, authHash: _authHash);
      if (await session.handshake()) {
        final client = TapoClient(session: session);
        return _Connection(
          getInfo: client.getDeviceInfo,
          setOn: client.setDeviceOn,
        );
      }
    }

    final session = TpapSession(
      deviceIp: ip,
      credentials: TpapCredentials(email: _email, password: _password),
    );
    if (!await session.handshake()) return null;

    // A network failure alone does not identify the device's protocol.
    _tpapDevices.add(ip);
    final client = TpapClient(session: session);
    return _Connection(
      getInfo: client.getDeviceInfo,
      setOn: client.setDeviceOn,
      close: session.close,
    );
  }

  /// Runs [command] on the plug at [ip]; null if the plug cannot be reached,
  /// fails the command, or was disconnected since [generation].
  Future<T?> _send<T>(
    String ip,
    int generation,
    Future<T?> Function(_Connection connection) command,
  ) => _queued(ip, () => _sendNow(ip, generation, command));

  /// A plug drops our session when it expires or when another app logs in to
  /// it: [command] then runs once more on a new session.
  Future<T?> _sendNow<T>(
    String ip,
    int generation,
    Future<T?> Function(_Connection connection) command, {
    bool retry = true,
  }) async {
    final connection = await _connect(ip, generation);
    if (connection == null) return null;

    try {
      final result = await command(connection);
      if (result != null) return result;
    } on SessionRejectedException {
      await _drop(ip, connection);
      if (!retry) return null;
      return await _sendNow(ip, generation, command, retry: false);
    } on Object {
      // A malformed reply raises Errors too (e.g. ArgumentError); it must not
      // fail a caller refreshing every plug at once.
    }

    // The session may be broken: the next command logs in again.
    await _drop(ip, connection);
    return null;
  }

  /// Forgets [connection], unless [disconnect] already did.
  Future<void> _drop(String ip, _Connection connection) async {
    if (identical(_connections[ip], connection)) _connections.remove(ip);
    await connection.close();
  }

  /// Get device state, returns TapoDevice (offline if unreachable)
  Future<TapoDevice> getDeviceState(String ip) =>
      _getDeviceState(ip, _generation(ip));

  Future<TapoDevice> _getDeviceState(String ip, int generation) async {
    final device = await _send(ip, generation, (connection) async {
      final info = await connection.getInfo();
      if (info == null) return null;
      return TapoDevice(
        ip: ip,
        nickname: info['nickname'] as String? ?? 'Tapo Device',
        model: info['model'] as String? ?? 'Unknown',
        deviceOn: info['device_on'] as bool? ?? false,
        isOnline: true,
      );
    });
    return device ?? _offlineDevice(ip);
  }

  /// Toggle device on/off, returns updated state
  Future<TapoDevice> toggleDevice(String ip) async {
    final generation = _generation(ip);
    final currentState = await _getDeviceState(ip, generation);
    return await _setDevicePower(
      ip,
      generation,
      currentState: currentState,
      on: !currentState.deviceOn,
    );
  }

  /// Set an explicit power state, returns the updated device state.
  Future<TapoDevice> setDevicePower(String ip, {required bool on}) async {
    final generation = _generation(ip);
    final currentState = await _getDeviceState(ip, generation);
    return await _setDevicePower(
      ip,
      generation,
      currentState: currentState,
      on: on,
    );
  }

  Future<TapoDevice> _setDevicePower(
    String ip,
    int generation, {
    required TapoDevice currentState,
    required bool on,
  }) async {
    if (!currentState.isOnline) return currentState;
    if (currentState.deviceOn == on) return currentState;

    // A plug disconnected since reading its state is not switched.
    final switched = await _send(
      ip,
      generation,
      (connection) async => await connection.setOn(on: on) ? true : null,
    );

    return switched == null
        ? currentState.copyWith(isOnline: false)
        : currentState.copyWith(deviceOn: on);
  }

  /// Disconnect from device (clear session). Work in progress on it stops
  /// instead of logging in again.
  Future<void> disconnect(String ip) async {
    _generations[ip] = _generation(ip) + 1;
    await _connections.remove(ip)?.close();
  }

  /// Disconnect from all devices
  Future<void> disconnectAll() async {
    final ips = {..._connections.keys, ..._queues.keys};
    await Future.wait(ips.map(disconnect));
  }
}

/// A logged-in session with one plug, over KLAP or TPAP.
class _Connection {
  _Connection({
    required this.getInfo,
    required this.setOn,
    this.close = _keepsNothingOpen,
  });

  final Future<Map<String, dynamic>?> Function() getInfo;
  final Future<bool> Function({required bool on}) setOn;
  final Future<void> Function() close;

  /// KLAP opens a socket per request.
  static Future<void> _keepsNothingOpen() async {}
}
