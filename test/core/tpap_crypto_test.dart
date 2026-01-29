import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/tpap_crypto.dart';

void main() {
  group('TpapHkdf', () {
    group('extract', () {
      test('returns 32 bytes', () {
        final salt = Uint8List.fromList(utf8.encode('salt'));
        final ikm = Uint8List.fromList(utf8.encode('input key material'));
        final result = TpapHkdf.extract(salt, ikm);
        expect(result.length, 32);
      });

      test('empty salt uses zero-filled salt', () {
        final ikm = Uint8List.fromList(utf8.encode('ikm'));
        final result1 = TpapHkdf.extract(Uint8List(0), ikm);
        final result2 = TpapHkdf.extract(Uint8List(32), ikm);
        expect(result1, result2);
      });

      test('different inputs produce different outputs', () {
        final salt = Uint8List.fromList(utf8.encode('salt'));
        final ikm1 = Uint8List.fromList(utf8.encode('ikm1'));
        final ikm2 = Uint8List.fromList(utf8.encode('ikm2'));
        expect(TpapHkdf.extract(salt, ikm1), isNot(equals(TpapHkdf.extract(salt, ikm2))));
      });
    });

    group('expand', () {
      test('returns requested length', () {
        final prk = Uint8List(32)..fillRange(0, 32, 0x42);
        final info = Uint8List.fromList(utf8.encode('info'));

        expect(TpapHkdf.expand(prk, info, 16).length, 16);
        expect(TpapHkdf.expand(prk, info, 32).length, 32);
        expect(TpapHkdf.expand(prk, info, 64).length, 64);
      });

      test('same inputs produce same output', () {
        final prk = Uint8List(32)..fillRange(0, 32, 0x11);
        final info = Uint8List.fromList(utf8.encode('context'));
        expect(TpapHkdf.expand(prk, info, 32), TpapHkdf.expand(prk, info, 32));
      });

      test('different info produces different output', () {
        final prk = Uint8List(32)..fillRange(0, 32, 0x22);
        final info1 = Uint8List.fromList(utf8.encode('info1'));
        final info2 = Uint8List.fromList(utf8.encode('info2'));
        expect(TpapHkdf.expand(prk, info1, 32), isNot(equals(TpapHkdf.expand(prk, info2, 32))));
      });
    });

    group('derive', () {
      test('combines extract and expand', () {
        final salt = Uint8List.fromList(utf8.encode('salt'));
        final ikm = Uint8List.fromList(utf8.encode('ikm'));
        final info = Uint8List.fromList(utf8.encode('info'));

        final prk = TpapHkdf.extract(salt, ikm);
        final expected = TpapHkdf.expand(prk, info, 32);
        final result = TpapHkdf.derive(salt, ikm, info, 32);

        expect(result, expected);
      });
    });
  });

  group('TpapSessionCipher', () {
    late TpapSessionCipher cipherAes128;
    late TpapSessionCipher cipherChaCha;

    setUp(() {
      cipherAes128 = TpapSessionCipher(
        key: Uint8List(16)..fillRange(0, 16, 0x42),
        baseNonce: Uint8List(12)..fillRange(0, 12, 0x24),
        cipherSuite: 1, // AES-128-CCM
      );

      cipherChaCha = TpapSessionCipher(
        key: Uint8List(32)..fillRange(0, 32, 0x55),
        baseNonce: Uint8List(12)..fillRange(0, 12, 0x66),
        cipherSuite: 3, // ChaCha20-Poly1305
      );
    });

    group('AES-CCM', () {
      test('encrypt then decrypt returns original', () {
        final plaintext = Uint8List.fromList(utf8.encode('Hello TPAP!'));
        final encrypted = cipherAes128.encrypt(plaintext);

        // Create new cipher with same params to decrypt (seq will match)
        final decryptCipher = TpapSessionCipher(
          key: Uint8List(16)..fillRange(0, 16, 0x42),
          baseNonce: Uint8List(12)..fillRange(0, 12, 0x24),
          cipherSuite: 1,
        );
        final decrypted = decryptCipher.decrypt(encrypted);

        expect(utf8.decode(decrypted), 'Hello TPAP!');
      });

      test('encrypted data includes tag (16 bytes longer)', () {
        final plaintext = Uint8List.fromList(utf8.encode('test'));
        final encrypted = cipherAes128.encrypt(plaintext);
        expect(encrypted.length, plaintext.length + 16);
      });

      test('sequence number increments on encrypt', () {
        final cipher = TpapSessionCipher(
          key: Uint8List(16),
          baseNonce: Uint8List(12),
          cipherSuite: 1,
        );
        expect(cipher.seq, 0);
        cipher.encrypt(Uint8List.fromList([1, 2, 3]));
        expect(cipher.seq, 1);
        cipher.encrypt(Uint8List.fromList([4, 5, 6]));
        expect(cipher.seq, 2);
      });

      test('sequence number increments on decrypt', () {
        final encryptCipher = TpapSessionCipher(
          key: Uint8List(16),
          baseNonce: Uint8List(12),
          cipherSuite: 1,
        );
        final encrypted = encryptCipher.encrypt(Uint8List.fromList([1, 2, 3]));

        final decryptCipher = TpapSessionCipher(
          key: Uint8List(16),
          baseNonce: Uint8List(12),
          cipherSuite: 1,
        );
        expect(decryptCipher.seq, 0);
        decryptCipher.decrypt(encrypted);
        expect(decryptCipher.seq, 1);
      });
    });

    group('ChaCha20-Poly1305', () {
      test('encrypt then decrypt returns original', () {
        final plaintext = Uint8List.fromList(utf8.encode('ChaCha test'));
        final encrypted = cipherChaCha.encrypt(plaintext);

        final decryptCipher = TpapSessionCipher(
          key: Uint8List(32)..fillRange(0, 32, 0x55),
          baseNonce: Uint8List(12)..fillRange(0, 12, 0x66),
          cipherSuite: 3,
        );
        final decrypted = decryptCipher.decrypt(encrypted);

        expect(utf8.decode(decrypted), 'ChaCha test');
      });
    });

    group('decryptWithSeq', () {
      test('decrypts without incrementing seq', () {
        final encCipher = TpapSessionCipher(
          key: Uint8List(16),
          baseNonce: Uint8List(12),
          cipherSuite: 1,
        );
        final encrypted = encCipher.encrypt(Uint8List.fromList([1, 2, 3]));

        final decCipher = TpapSessionCipher(
          key: Uint8List(16),
          baseNonce: Uint8List(12),
          cipherSuite: 1,
        );
        // decryptWithSeq should not change seq
        final decrypted = decCipher.decryptWithSeq(encrypted, 1);
        expect(decCipher.seq, 0);
        expect(decrypted, Uint8List.fromList([1, 2, 3]));
      });
    });

    group('unsupported cipher suite', () {
      test('encrypt throws for unknown cipher suite', () {
        final cipher = TpapSessionCipher(
          key: Uint8List(16),
          baseNonce: Uint8List(12),
          cipherSuite: 99,
        );
        expect(
          () => cipher.encrypt(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('decrypt throws for unknown cipher suite', () {
        final cipher = TpapSessionCipher(
          key: Uint8List(16),
          baseNonce: Uint8List(12),
          cipherSuite: 99,
        );
        expect(
          () => cipher.decrypt(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('startSeq', () {
      test('starts from provided sequence number', () {
        final cipher = TpapSessionCipher(
          key: Uint8List(16),
          baseNonce: Uint8List(12),
          cipherSuite: 1,
          startSeq: 100,
        );
        expect(cipher.seq, 100);
        cipher.encrypt(Uint8List.fromList([1]));
        expect(cipher.seq, 101);
      });
    });
  });

  group('md5Hash', () {
    test('returns correct hash for known input', () {
      // MD5("hello") = 5d41402abc4b2a76b9719d911017c592
      expect(md5Hash('hello'), '5d41402abc4b2a76b9719d911017c592');
    });

    test('returns correct hash for empty string', () {
      // MD5("") = d41d8cd98f00b204e9800998ecf8427e
      expect(md5Hash(''), 'd41d8cd98f00b204e9800998ecf8427e');
    });
  });

  group('generateTpapAuthHash', () {
    test('returns 32 bytes', () {
      final result = generateTpapAuthHash('test@example.com', 'password');
      expect(result.length, 32);
    });

    test('same inputs produce same output', () {
      final hash1 = generateTpapAuthHash('user@example.com', 'pass');
      final hash2 = generateTpapAuthHash('user@example.com', 'pass');
      expect(hash1, hash2);
    });

    test('different emails produce different output', () {
      final hash1 = generateTpapAuthHash('user1@example.com', 'pass');
      final hash2 = generateTpapAuthHash('user2@example.com', 'pass');
      expect(hash1, isNot(equals(hash2)));
    });
  });
}
