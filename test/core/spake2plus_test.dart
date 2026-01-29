import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/spake2plus.dart';

void main() {
  group('Spake2Plus', () {
    test('creates instance with required parameters', () {
      final spake = Spake2Plus(
        identity: 'user@example.com',
        password: 'password123',
      );

      expect(spake.identity, 'user@example.com');
      expect(spake.password, 'password123');
      expect(spake.iterations, 1000); // default
    });

    test('creates instance with custom iterations', () {
      final spake = Spake2Plus(
        identity: 'user@example.com',
        password: 'password123',
        iterations: 5000,
      );

      expect(spake.iterations, 5000);
    });

    test('creates instance with custom salt', () {
      final salt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final spake = Spake2Plus(
        identity: 'user@example.com',
        password: 'password123',
        salt: salt,
      );

      expect(spake.salt, salt);
    });

    group('generatePublicShare', () {
      test('returns compressed point (33 bytes)', () {
        final spake = Spake2Plus(
          identity: 'user@example.com',
          password: 'testpass',
        );

        final serverSalt = Uint8List.fromList(List.generate(16, (i) => i));
        final share = spake.generatePublicShare(serverSalt, 1000);

        // Compressed P-256 point is 33 bytes (0x02/0x03 prefix + 32 bytes)
        expect(share.length, 33);
        expect(share[0] == 0x02 || share[0] == 0x03, isTrue);
      });

      test('different calls produce different shares (random ephemeral)', () {
        final spake1 = Spake2Plus(
          identity: 'user@example.com',
          password: 'testpass',
        );
        final spake2 = Spake2Plus(
          identity: 'user@example.com',
          password: 'testpass',
        );

        final salt = Uint8List(16);
        final share1 = spake1.generatePublicShare(salt, 1000);
        final share2 = spake2.generatePublicShare(salt, 1000);

        // Due to random ephemeral key, shares should differ
        expect(share1, isNot(equals(share2)));
      });
    });

    group('processServerShare', () {
      test('returns null before generatePublicShare called', () {
        final spake = Spake2Plus(
          identity: 'user@example.com',
          password: 'testpass',
        );

        // Create a fake server share (compressed point)
        final fakeServerShare = Uint8List(33);
        fakeServerShare[0] = 0x02;

        final result = spake.processServerShare(fakeServerShare);
        expect(result, isNull);
      });

      test('throws or returns null for invalid point encoding', () {
        final spake = Spake2Plus(
          identity: 'user@example.com',
          password: 'testpass',
        );

        spake.generatePublicShare(Uint8List(16), 1000);

        // Invalid point encoding - may throw or return null depending on error type
        final invalidShare = Uint8List.fromList([0xFF, ...List.filled(32, 0)]);
        try {
          final result = spake.processServerShare(invalidShare);
          expect(result, isNull);
        } catch (e) {
          // ArgumentError from pointycastle is acceptable
          expect(e, isA<ArgumentError>());
        }
      });
    });

    group('verifyServerConfirmation', () {
      test('returns false before processServerShare', () {
        final spake = Spake2Plus(
          identity: 'user@example.com',
          password: 'testpass',
        );

        final result = spake.verifyServerConfirmation(Uint8List(32));
        expect(result, isFalse);
      });
    });

    group('sharedKey', () {
      test('is null initially', () {
        final spake = Spake2Plus(
          identity: 'user@example.com',
          password: 'testpass',
        );

        expect(spake.sharedKey, isNull);
      });
    });
  });
}
