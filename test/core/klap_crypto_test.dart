import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/klap_crypto.dart';

void main() {
  group('sha1Hash', () {
    test('returns correct hex string for known input', () {
      // SHA1("hello") = aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d
      expect(sha1Hash('hello'), 'aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d');
    });

    test('returns correct hash for empty string', () {
      // SHA1("") = da39a3ee5e6b4b0d3255bfef95601890afd80709
      expect(sha1Hash(''), 'da39a3ee5e6b4b0d3255bfef95601890afd80709');
    });
  });

  group('sha1HashBytes', () {
    test('returns 20 bytes', () {
      final result = sha1HashBytes('test');
      expect(result.length, 20);
    });

    test('matches hex version', () {
      final bytes = sha1HashBytes('hello');
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, sha1Hash('hello'));
    });
  });

  group('sha256HashBytes', () {
    test('returns 32 bytes', () {
      final result = sha256HashBytes(utf8.encode('test'));
      expect(result.length, 32);
    });

    test('returns correct hash for known input', () {
      // SHA256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
      final result = sha256Hash(utf8.encode('hello'));
      expect(result, '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824');
    });
  });

  group('sha256Hash', () {
    test('returns 64 character hex string', () {
      final result = sha256Hash(utf8.encode('test'));
      expect(result.length, 64);
    });
  });

  group('generateAuthHash', () {
    test('returns 32 bytes (SHA256 output)', () {
      final result = generateAuthHash('test@example.com', 'password');
      expect(result.length, 32);
    });

    test('same inputs produce same output', () {
      final hash1 = generateAuthHash('user@example.com', 'pass123');
      final hash2 = generateAuthHash('user@example.com', 'pass123');
      expect(hash1, hash2);
    });

    test('different emails produce different output', () {
      final hash1 = generateAuthHash('user1@example.com', 'password');
      final hash2 = generateAuthHash('user2@example.com', 'password');
      expect(hash1, isNot(equals(hash2)));
    });

    test('different passwords produce different output', () {
      final hash1 = generateAuthHash('user@example.com', 'password1');
      final hash2 = generateAuthHash('user@example.com', 'password2');
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('aesEncrypt/aesDecrypt', () {
    test('encrypt then decrypt returns original data', () {
      final data = Uint8List.fromList(utf8.encode('Hello, World!'));
      final key = Uint8List(16)..fillRange(0, 16, 0x42); // 16-byte key
      final iv = Uint8List(16)..fillRange(0, 16, 0x24); // 16-byte IV

      final encrypted = aesEncrypt(data, key, iv);
      final decrypted = aesDecrypt(encrypted, key, iv);

      expect(utf8.decode(decrypted), 'Hello, World!');
    });

    test('encrypt produces different output than input', () {
      final data = Uint8List.fromList(utf8.encode('secret message'));
      final key = Uint8List(16)..fillRange(0, 16, 0xAB);
      final iv = Uint8List(16)..fillRange(0, 16, 0xCD);

      final encrypted = aesEncrypt(data, key, iv);
      expect(encrypted, isNot(equals(data)));
    });

    test('encrypted data length is padded to block boundary', () {
      final data = Uint8List.fromList(utf8.encode('test')); // 4 bytes
      final key = Uint8List(16);
      final iv = Uint8List(16);

      final encrypted = aesEncrypt(data, key, iv);
      // Should be padded to 16 bytes (one block)
      expect(encrypted.length, 16);
    });

    test('decryption with wrong key fails or produces garbage', () {
      final data = Uint8List.fromList(utf8.encode('Hello'));
      final key1 = Uint8List(16)..fillRange(0, 16, 0x11);
      final key2 = Uint8List(16)..fillRange(0, 16, 0x22);
      final iv = Uint8List(16);

      final encrypted = aesEncrypt(data, key1, iv);

      // Decrypting with wrong key should throw due to invalid padding
      expect(
        () => aesDecrypt(encrypted, key2, iv),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles exact block size data', () {
      // 16 bytes = exactly one block
      final data = Uint8List.fromList(utf8.encode('0123456789ABCDEF'));
      final key = Uint8List(16)..fillRange(0, 16, 0x33);
      final iv = Uint8List(16)..fillRange(0, 16, 0x44);

      final encrypted = aesEncrypt(data, key, iv);
      // PKCS7 adds full block of padding when data is exact multiple
      expect(encrypted.length, 32);

      final decrypted = aesDecrypt(encrypted, key, iv);
      expect(utf8.decode(decrypted), '0123456789ABCDEF');
    });
  });

  group('bytesEqual', () {
    test('returns true for identical arrays', () {
      final a = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(bytesEqual(a, b), isTrue);
    });

    test('returns false for different arrays', () {
      final a = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b = Uint8List.fromList([1, 2, 3, 4, 6]);
      expect(bytesEqual(a, b), isFalse);
    });

    test('returns false for different lengths', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([1, 2, 3, 4]);
      expect(bytesEqual(a, b), isFalse);
    });

    test('returns true for empty arrays', () {
      final a = Uint8List(0);
      final b = Uint8List(0);
      expect(bytesEqual(a, b), isTrue);
    });

    test('returns false when first byte differs', () {
      final a = Uint8List.fromList([0, 2, 3]);
      final b = Uint8List.fromList([1, 2, 3]);
      expect(bytesEqual(a, b), isFalse);
    });

    test('returns false when last byte differs', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([1, 2, 4]);
      expect(bytesEqual(a, b), isFalse);
    });
  });
}
