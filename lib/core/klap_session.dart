import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tapo/core/http_utils.dart';
import 'package:tapo/core/klap_crypto.dart';

/// KLAP session for communicating with Tapo devices
/// Matches python-kasa KlapEncryptionSession implementation
class KlapSession {
  KlapSession({required this.deviceIp, required this.authHash});

  final String deviceIp;
  final Uint8List authHash;

  String? sessionCookie;
  Uint8List? _localSeed;
  Uint8List? _remoteSeed;

  // Derived session values (matches python-kasa)
  Uint8List? _key; // 16 bytes
  Uint8List? _iv; // 12 bytes
  Uint8List? _sig; // 28 bytes
  int seq = 0;

  Uint8List? get key => _key;
  Uint8List? get sig => _sig;

  /// Perform KLAP two-stage handshake
  Future<bool> handshake() async {
    try {
      if (!await _handshake1()) return false;
      if (!await _handshake2()) return false;
      _deriveSessionKeys();
      return true;
    } on Exception {
      return false;
    }
  }

  /// Stage 1: Send local seed, receive remote seed + server hash
  Future<bool> _handshake1() async {
    _localSeed = _generateRandomBytes(16);

    final socket = await Socket.connect(deviceIp, 80);
    final request = 'POST /app/handshake1 HTTP/1.1\r\n'
        'Host: $deviceIp\r\n'
        'Content-Type: application/octet-stream\r\n'
        'Content-Length: 16\r\n'
        'Accept: */*\r\n'
        '\r\n';

    socket
      ..add(utf8.encode(request))
      ..add(_localSeed!);

    final response = await readHttpResponse(socket);
    await socket.close();

    if (response.statusCode != 200 || response.body.length != 48) return false;

    _remoteSeed = Uint8List.sublistView(response.body, 0, 16);
    final serverHash = Uint8List.sublistView(response.body, 16, 48);

    // Verify: SHA256(localSeed + remoteSeed + authHash)
    final expected = sha256HashBytes([
      ..._localSeed!,
      ..._remoteSeed!,
      ...authHash,
    ]);
    if (!bytesEqual(serverHash, expected)) return false;

    if (response.cookie != null) {
      sessionCookie = response.cookie;
    }

    return true;
  }

  /// Stage 2: Send client hash to verify auth
  Future<bool> _handshake2() async {
    if (_localSeed == null || _remoteSeed == null || sessionCookie == null) {
      return false;
    }

    final clientHash = sha256HashBytes([
      ..._remoteSeed!,
      ..._localSeed!,
      ...authHash,
    ]);

    final socket = await Socket.connect(deviceIp, 80);
    final request = 'POST /app/handshake2 HTTP/1.1\r\n'
        'Host: $deviceIp\r\n'
        'Content-Type: application/octet-stream\r\n'
        'Content-Length: 32\r\n'
        'Cookie: $sessionCookie\r\n'
        'Accept: */*\r\n'
        '\r\n';

    socket
      ..add(utf8.encode(request))
      ..add(clientHash);

    final response = await readHttpResponse(socket);
    await socket.close();

    return response.statusCode == 200;
  }

  /// Derive session keys (matches python-kasa exactly)
  void _deriveSessionKeys() {
    // Key: SHA256("lsk" + localSeed + remoteSeed + authHash)[:16]
    final keyPayload = sha256HashBytes([
      ...utf8.encode('lsk'),
      ..._localSeed!,
      ..._remoteSeed!,
      ...authHash,
    ]);
    _key = Uint8List.sublistView(keyPayload, 0, 16);

    // IV + Seq: SHA256("iv" + localSeed + remoteSeed + authHash)
    // iv = [:12], seq = [-4:] as signed big-endian int32
    final ivPayload = sha256HashBytes([
      ...utf8.encode('iv'),
      ..._localSeed!,
      ..._remoteSeed!,
      ...authHash,
    ]);
    _iv = Uint8List.sublistView(ivPayload, 0, 12);
    seq = ByteData.sublistView(ivPayload, 28, 32).getInt32(0);

    // Sig: SHA256("ldk" + localSeed + remoteSeed + authHash)[:28]
    final sigPayload = sha256HashBytes([
      ...utf8.encode('ldk'),
      ..._localSeed!,
      ..._remoteSeed!,
      ...authHash,
    ]);
    _sig = Uint8List.sublistView(sigPayload, 0, 28);
  }

  /// Generate IV for current seq: iv (12 bytes) + seq (4 bytes big-endian)
  Uint8List generateIv() {
    final iv = Uint8List(16)..setAll(0, _iv!);
    final seqBytes = ByteData(4)..setInt32(0, seq);
    iv.setAll(12, seqBytes.buffer.asUint8List());
    return iv;
  }

  bool get isEstablished => _key != null && _iv != null && _sig != null;

  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }
}
