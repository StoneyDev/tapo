import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'klap_crypto.dart';

/// KLAP session for communicating with Tapo devices
class KlapSession {
  final String deviceIp;
  final Uint8List authHash;

  String? sessionCookie;
  Uint8List? key;
  Uint8List? iv;
  int seq = 0;

  Uint8List? _localSeed;
  Uint8List? _remoteSeed;
  Uint8List? _serverHash;

  KlapSession({required this.deviceIp, required this.authHash});

  String get _baseUrl => 'http://$deviceIp/app';

  /// Perform KLAP two-stage handshake
  /// Returns true on success, false on failure
  Future<bool> handshake() async {
    try {
      // Stage 1: handshake1 - send local seed, get remote seed
      final stage1Success = await _handshake1();
      if (!stage1Success) return false;

      // Stage 2: handshake2 - verify auth, get session established
      final stage2Success = await _handshake2();
      if (!stage2Success) return false;

      // Derive encryption key and IV
      _deriveKeyAndIv();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stage 1: POST /app/handshake1
  /// Send 16-byte local seed, receive 16-byte remote seed + 32-byte server hash
  Future<bool> _handshake1() async {
    _localSeed = _generateRandomBytes(16);

    final response = await http.post(
      Uri.parse('$_baseUrl/handshake1'),
      body: _localSeed,
    );

    if (response.statusCode != 200) return false;

    final body = response.bodyBytes;
    if (body.length != 48) return false; // 16 remote seed + 32 server hash

    _remoteSeed = Uint8List.sublistView(body, 0, 16);
    _serverHash = Uint8List.sublistView(body, 16, 48);

    // Extract session cookie
    final cookie = response.headers['set-cookie'];
    if (cookie != null) {
      sessionCookie = cookie.split(';').first;
    }

    return true;
  }

  /// Stage 2: POST /app/handshake2
  /// Send client hash to verify auth
  Future<bool> _handshake2() async {
    if (_localSeed == null || _remoteSeed == null || sessionCookie == null) {
      return false;
    }

    // Client hash = SHA256(remoteSeed + localSeed + authHash)
    final clientHash = sha256HashBytes([
      ..._remoteSeed!,
      ..._localSeed!,
      ...authHash,
    ]);

    final response = await http.post(
      Uri.parse('$_baseUrl/handshake2'),
      headers: {'Cookie': sessionCookie!},
      body: clientHash,
    );

    return response.statusCode == 200;
  }

  /// Derive encryption key and IV from seeds
  /// Key = SHA256(localSeed + remoteSeed + authHash)[0:16]
  /// IV = SHA256("iv" + localSeed + remoteSeed + authHash)[0:12] padded to 16
  void _deriveKeyAndIv() {
    if (_localSeed == null || _remoteSeed == null) return;

    // Key derivation
    final keyMaterial = sha256HashBytes([
      ..._localSeed!,
      ..._remoteSeed!,
      ...authHash,
    ]);
    key = Uint8List.sublistView(keyMaterial, 0, 16);

    // IV derivation: SHA256("iv" + localSeed + remoteSeed + authHash)[0:12]
    final ivPrefix = utf8.encode('iv');
    final ivMaterial = sha256HashBytes([
      ...ivPrefix,
      ..._localSeed!,
      ..._remoteSeed!,
      ...authHash,
    ]);
    // IV is first 12 bytes, but AES needs 16, so we'll use seq to fill
    iv = Uint8List.sublistView(ivMaterial, 0, 12);

    // Derive initial seq from SHA256("seq" + localSeed + remoteSeed + authHash)
    final seqPrefix = utf8.encode('seq');
    final seqMaterial = sha256HashBytes([
      ...seqPrefix,
      ..._localSeed!,
      ..._remoteSeed!,
      ...authHash,
    ]);
    // seq is signed 32-bit int from first 4 bytes
    seq = ByteData.sublistView(seqMaterial, 0, 4).getInt32(0, Endian.big);
  }

  /// Generate cryptographically random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Check if session is established
  bool get isEstablished => key != null && iv != null && sessionCookie != null;

  /// Get IV for current sequence number (12-byte base IV + 4-byte seq counter)
  Uint8List getIvForSeq(int seqNum) {
    if (iv == null) throw StateError('Session not established');
    final fullIv = Uint8List(16);
    fullIv.setAll(0, iv!);
    // Last 4 bytes are seq number as big-endian
    final seqBytes = ByteData(4)..setInt32(0, seqNum, Endian.big);
    fullIv.setAll(12, seqBytes.buffer.asUint8List());
    return fullIv;
  }
}
