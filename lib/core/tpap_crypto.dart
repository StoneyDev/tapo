import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// AEAD cipher for TPAP encrypted communication
/// Supports AES-128-CCM, AES-256-CCM, and ChaCha20-Poly1305
class TpapSessionCipher {
  TpapSessionCipher({
    required this.key,
    required this.baseNonce,
    required this.cipherSuite,
    this.startSeq = 0,
  }) : _seq = startSeq;

  final Uint8List key;
  final Uint8List baseNonce;
  final int cipherSuite;
  final int startSeq;
  int _seq;

  int get seq => _seq;

  /// Encrypt data with AEAD
  Uint8List encrypt(Uint8List plaintext) {
    _seq++;
    final nonce = _generateNonce(_seq);

    switch (cipherSuite) {
      case 1: // AES-128-CCM
      case 2: // AES-256-CCM
        return _encryptCcm(plaintext, nonce);
      case 3: // ChaCha20-Poly1305
        return _encryptChaCha20Poly1305(plaintext, nonce);
      default:
        throw UnsupportedError('Cipher suite $cipherSuite not supported');
    }
  }

  /// Decrypt data with AEAD
  Uint8List decrypt(Uint8List ciphertext) {
    _seq++;
    final nonce = _generateNonce(_seq);

    switch (cipherSuite) {
      case 1: // AES-128-CCM
      case 2: // AES-256-CCM
        return _decryptCcm(ciphertext, nonce);
      case 3: // ChaCha20-Poly1305
        return _decryptChaCha20Poly1305(ciphertext, nonce);
      default:
        throw UnsupportedError('Cipher suite $cipherSuite not supported');
    }
  }

  /// Decrypt without incrementing seq (for retries)
  Uint8List decryptWithSeq(Uint8List ciphertext, int seqNum) {
    final nonce = _generateNonce(seqNum);

    switch (cipherSuite) {
      case 1:
      case 2:
        return _decryptCcm(ciphertext, nonce);
      case 3:
        return _decryptChaCha20Poly1305(ciphertext, nonce);
      default:
        throw UnsupportedError('Cipher suite $cipherSuite not supported');
    }
  }

  Uint8List _generateNonce(int seqNum) {
    // Nonce = baseNonce (first 8 bytes) + seq (4 bytes big-endian)
    final nonce = Uint8List(12)..setAll(0, baseNonce.sublist(0, 8));
    final seqBytes = ByteData(4)..setInt32(0, seqNum);
    nonce.setAll(8, seqBytes.buffer.asUint8List());
    return nonce;
  }

  Uint8List _encryptCcm(Uint8List plaintext, Uint8List nonce) {
    // AES-CCM with 16 byte tag
    final ccm = CCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128, // tag length in bits
          nonce,
          Uint8List(0), // no AAD
        ),
      );

    final output = Uint8List(plaintext.length + 16); // plaintext + tag
    final len = ccm.processBytes(plaintext, 0, plaintext.length, output, 0);
    ccm.doFinal(output, len);
    return output;
  }

  Uint8List _decryptCcm(Uint8List ciphertext, Uint8List nonce) {
    final ccm = CCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          128, // tag length in bits
          nonce,
          Uint8List(0), // no AAD
        ),
      );

    final output = Uint8List(ciphertext.length - 16); // remove tag
    final len = ccm.processBytes(ciphertext, 0, ciphertext.length, output, 0);
    ccm.doFinal(output, len);
    return output;
  }

  Uint8List _encryptChaCha20Poly1305(Uint8List plaintext, Uint8List nonce) {
    final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128, // tag length
          nonce,
          Uint8List(0),
        ),
      );

    final output = Uint8List(plaintext.length + 16);
    final len = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
    cipher.doFinal(output, len);
    return output;
  }

  Uint8List _decryptChaCha20Poly1305(Uint8List ciphertext, Uint8List nonce) {
    final cipher = ChaCha20Poly1305(
      ChaCha7539Engine(),
      Poly1305(),
    )..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

    final output = Uint8List(ciphertext.length - 16);
    final len = cipher.processBytes(
      ciphertext,
      0,
      ciphertext.length,
      output,
      0,
    );
    cipher.doFinal(output, len);
    return output;
  }
}

/// HKDF key derivation for TPAP
class TpapHkdf {
  /// HKDF-SHA256 Extract
  static Uint8List extract(Uint8List salt, Uint8List ikm) {
    final hmac = Hmac(sha256, salt.isEmpty ? Uint8List(32) : salt);
    return Uint8List.fromList(hmac.convert(ikm).bytes);
  }

  static const _hashLen = 32;

  /// HKDF-SHA256 Expand
  static Uint8List expand(Uint8List prk, Uint8List info, int length) {
    final n = (length + _hashLen - 1) ~/ _hashLen;
    final okm = BytesBuilder();
    var t = Uint8List(0);

    for (var i = 1; i <= n; i++) {
      final input = BytesBuilder()
        ..add(t)
        ..add(info)
        ..add([i]);
      final hmacResult = Hmac(sha256, prk).convert(input.toBytes());
      t = Uint8List.fromList(hmacResult.bytes);
      okm.add(t);
    }

    return Uint8List.sublistView(okm.toBytes(), 0, length);
  }

  /// Full HKDF (extract + expand)
  static Uint8List derive(
    Uint8List salt,
    Uint8List ikm,
    Uint8List info,
    int length,
  ) {
    final prk = extract(salt, ikm);
    return expand(prk, info, length);
  }
}

/// MD5 crypt for legacy credential handling
String md5Hash(String input) {
  return md5.convert(utf8.encode(input)).toString();
}

/// Generate credential hash for TPAP (similar to KLAP but may differ)
Uint8List generateTpapAuthHash(String email, String password) {
  // TPAP uses the same hash as KLAP: SHA256(SHA1(email) + SHA1(password))
  final emailSha1 = sha1.convert(utf8.encode(email)).bytes;
  final passwordSha1 = sha1.convert(utf8.encode(password)).bytes;
  final combined = [...emailSha1, ...passwordSha1];
  return Uint8List.fromList(sha256.convert(combined).bytes);
}
