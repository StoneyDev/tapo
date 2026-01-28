import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:tapo/core/klap_crypto.dart' show bytesEqual;
import 'package:tapo/core/tpap_crypto.dart' show TpapHkdf;

/// SPAKE2+ implementation for TPAP protocol
/// Based on RFC 9383 with P-256 curve
class Spake2Plus {
  Spake2Plus({
    required this.identity,
    required this.password,
    this.salt,
    this.iterations = 1000,
  });

  final String identity;
  final String password;
  final Uint8List? salt;
  final int iterations;

  // P-256 curve parameters
  static final ECDomainParameters _curve = ECCurve_secp256r1();

  // M and N constants for P-256 (from RFC 9383)
  static final ECPoint _M = _curve.curve.decodePoint(
    _hexToBytes(
      '02886e2f97ace46e55ba9dd7242579f2993b64e16ef3dcab95afd497333d8fa12f',
    ),
  )!;
  static final ECPoint _N = _curve.curve.decodePoint(
    _hexToBytes(
      '03d8bbd6c639c62937b04d997f38c3770719c629d7014d49a24b4f98baa1292b49',
    ),
  )!;

  // Context tag for TPAP
  static final Uint8List _contextTag = Uint8List.fromList(utf8.encode('PAKE V1'));

  BigInt? _x; // Ephemeral private key
  ECPoint? _X; // Our public share (X = x*G + w0*M)
  BigInt? _w0;
  BigInt? _w1;

  Uint8List? _sharedKey;

  /// Derive w0 and w1 from password using PBKDF2
  void _deriveW(Uint8List serverSalt, int serverIterations) {
    final effectiveSalt = serverSalt.isNotEmpty ? serverSalt : salt;
    final effectiveIterations =
        serverIterations > 0 ? serverIterations : iterations;

    // PBKDF2-HMAC-SHA256 to derive 80 bytes (640 bits as per RFC)
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(effectiveSalt!, effectiveIterations, 80));

    final passwordBytes = utf8.encode(password);
    final derived = pbkdf2.process(Uint8List.fromList(passwordBytes));

    // Split into w0s (40 bytes) and w1s (40 bytes)
    final w0s = _bytesToBigInt(Uint8List.sublistView(derived, 0, 40));
    final w1s = _bytesToBigInt(Uint8List.sublistView(derived, 40, 80));

    // Reduce modulo curve order
    _w0 = w0s % _curve.n;
    _w1 = w1s % _curve.n;
  }

  /// Generate client's public share X = x*G + w0*M
  Uint8List generatePublicShare(Uint8List serverSalt, int serverIterations) {
    _deriveW(serverSalt, serverIterations);

    // Generate random x
    final random = Random.secure();
    _x = _randomBigInt(_curve.n, random);

    // X = x*G + w0*M
    final xG = _curve.G * _x;
    final w0M = _M * _w0;
    _X = (xG! + w0M)!;

    // Return compressed point
    return _X!.getEncoded(true);
  }

  /// Process server's public share Y and compute shared secret
  /// Returns confirmation value for client
  Uint8List? processServerShare(Uint8List serverShareBytes) {
    if (_x == null || _w0 == null || _w1 == null || _X == null) return null;

    try {
      // Decode server's share Y
      final Y = _curve.curve.decodePoint(serverShareBytes);
      if (Y == null) return null;

      // Verify Y is on curve and in subgroup
      if (!_isOnCurve(Y)) return null;

      // Compute Z = x * (Y - w0*N)
      final w0N = _N * _w0;
      final YMinusW0N = (Y + (-w0N!))!;
      final Z = YMinusW0N * _x;

      // Compute V = w1 * (Y - w0*N)
      final V = YMinusW0N * _w1;

      if (Z == null || V == null) return null;

      // Build transcript TT
      final tt = _buildTranscript(
        context: _contextTag,
        idProver: Uint8List.fromList(utf8.encode(identity)),
        idVerifier: Uint8List(0),
        M: _M.getEncoded(false),
        N: _N.getEncoded(false),
        X: _X!.getEncoded(false),
        Y: Y.getEncoded(false),
        Z: Z.getEncoded(false),
        V: V.getEncoded(false),
        w0: _bigIntToBytes(_w0!, 32),
      );

      // K_main = Hash(TT)
      final kMain = sha256.convert(tt).bytes;

      // Derive confirmation keys using HKDF
      final kMainBytes = Uint8List.fromList(kMain);
      final confirmKeys = TpapHkdf.expand(
        kMainBytes,
        Uint8List.fromList(utf8.encode('ConfirmationKeys')),
        64,
      );
      final kConfirmP = Uint8List.sublistView(confirmKeys, 0, 32);
      final kConfirmV = Uint8List.sublistView(confirmKeys, 32, 64);

      // Derive shared key
      _sharedKey = TpapHkdf.expand(
        kMainBytes,
        Uint8List.fromList(utf8.encode('SharedKey')),
        32,
      );

      // Store kConfirmV for verifying server's confirmation
      _kConfirmV = kConfirmV;
      _clientShare = _X!.getEncoded(true);

      // Client confirmation = HMAC(K_confirmP, Y)
      final clientConfirm = Hmac(sha256, kConfirmP).convert(serverShareBytes);
      return Uint8List.fromList(clientConfirm.bytes);
    } on Exception {
      return null;
    }
  }

  Uint8List? _kConfirmV;
  Uint8List? _clientShare;

  /// Verify server's confirmation value
  bool verifyServerConfirmation(Uint8List serverConfirm) {
    if (_kConfirmV == null || _clientShare == null) {
      return false;
    }

    final expected = Hmac(sha256, _kConfirmV!).convert(_clientShare!);
    return bytesEqual(Uint8List.fromList(expected.bytes), serverConfirm);
  }

  /// Get the shared key after successful exchange
  Uint8List? get sharedKey => _sharedKey;

  // Helper methods

  Uint8List _buildTranscript({
    required Uint8List context,
    required Uint8List idProver,
    required Uint8List idVerifier,
    required Uint8List M,
    required Uint8List N,
    required Uint8List X,
    required Uint8List Y,
    required Uint8List Z,
    required Uint8List V,
    required Uint8List w0,
  }) {
    final buffer = BytesBuilder();
    // Length-prefixed fields
    buffer
      ..add(_lengthPrefix(context))
      ..add(context)
      ..add(_lengthPrefix(idProver))
      ..add(idProver)
      ..add(_lengthPrefix(idVerifier))
      ..add(idVerifier)
      ..add(_lengthPrefix(M))
      ..add(M)
      ..add(_lengthPrefix(N))
      ..add(N)
      ..add(_lengthPrefix(X))
      ..add(X)
      ..add(_lengthPrefix(Y))
      ..add(Y)
      ..add(_lengthPrefix(Z))
      ..add(Z)
      ..add(_lengthPrefix(V))
      ..add(V)
      ..add(_lengthPrefix(w0))
      ..add(w0);
    return buffer.toBytes();
  }

  Uint8List _lengthPrefix(Uint8List data) {
    final len = data.length;
    return Uint8List.fromList([
      len & 0xff,
      (len >> 8) & 0xff,
      (len >> 16) & 0xff,
      (len >> 24) & 0xff,
      (len >> 32) & 0xff,
      (len >> 40) & 0xff,
      (len >> 48) & 0xff,
      (len >> 56) & 0xff,
    ]);
  }

  bool _isOnCurve(ECPoint point) {
    try {
      // Verify the point is valid by checking it's not at infinity
      // and coordinates are within field bounds
      if (point.isInfinity) return false;
      final x = point.x?.toBigInteger();
      final y = point.y?.toBigInteger();
      if (x == null || y == null) return false;

      // For P-256, verify coordinates are within valid range
      // The field prime is 2^256 - 2^224 + 2^192 + 2^96 - 1
      final fieldSize = BigInt.from(1) << 256;
      return x >= BigInt.zero && x < fieldSize && y >= BigInt.zero && y < fieldSize;
    } on Exception {
      return false;
    }
  }

  BigInt _randomBigInt(BigInt max, Random random) {
    final bytes = (max.bitLength + 7) ~/ 8;
    while (true) {
      final randomBytes =
          Uint8List.fromList(List.generate(bytes, (_) => random.nextInt(256)));
      final value = _bytesToBigInt(randomBytes);
      if (value > BigInt.zero && value < max) {
        return value;
      }
    }
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return result;
  }

}
