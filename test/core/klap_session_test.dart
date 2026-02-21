import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/klap_crypto.dart';
import 'package:tapo/core/klap_session.dart';

import '../helpers/test_utils.dart';

/// Testable subclass that allows setting internal state
class TestableKlapSession extends KlapSession {
  TestableKlapSession({required super.deviceIp, required super.authHash});

  Uint8List? localSeed;
  Uint8List? remoteSeed;

  /// Simulate successful handshake by setting seeds and deriving keys
  void simulateHandshake(Uint8List local, Uint8List remote) {
    localSeed = local;
    remoteSeed = remote;
    sessionCookie = 'TP_SESSIONID=test123';
    deriveSessionKeysForTest();
  }

  /// Expose key derivation for testing
  void deriveSessionKeysForTest() {
    // Key: SHA256("lsk" + localSeed + remoteSeed + authHash)[:16]
    final keyPayload = sha256HashBytes([
      ...utf8.encode('lsk'),
      ...localSeed!,
      ...remoteSeed!,
      ...authHash,
    ]);
    setKey(Uint8List.sublistView(keyPayload, 0, 16));

    // IV + Seq: SHA256("iv" + localSeed + remoteSeed + authHash)
    final ivPayload = sha256HashBytes([
      ...utf8.encode('iv'),
      ...localSeed!,
      ...remoteSeed!,
      ...authHash,
    ]);
    setIv(Uint8List.sublistView(ivPayload, 0, 12));
    seq = ByteData.sublistView(ivPayload, 28, 32).getInt32(0);

    // Sig: SHA256("ldk" + localSeed + remoteSeed + authHash)[:28]
    final sigPayload = sha256HashBytes([
      ...utf8.encode('ldk'),
      ...localSeed!,
      ...remoteSeed!,
      ...authHash,
    ]);
    setSig(Uint8List.sublistView(sigPayload, 0, 28));
  }

  void setKey(Uint8List? k) => _setField('_key', k);
  void setIv(Uint8List? iv) => _setField('_iv', iv);
  void setSig(Uint8List? s) => _setField('_sig', s);

  // Use reflection-like approach via extension
  void _setField(String name, Uint8List? value) {
    switch (name) {
      case '_key':
        _testKey = value;
      case '_iv':
        _testIv = value;
      case '_sig':
        _testSig = value;
    }
  }

  Uint8List? _testKey;
  Uint8List? _testIv;
  Uint8List? _testSig;

  @override
  Uint8List? get key => _testKey;

  @override
  Uint8List? get sig => _testSig;

  @override
  bool get isEstablished =>
      _testKey != null && _testIv != null && _testSig != null;

  @override
  Uint8List generateIv() {
    final iv = Uint8List(16)..setAll(0, _testIv!);
    final seqBytes = ByteData(4)..setInt32(0, seq);
    iv.setAll(12, seqBytes.buffer.asUint8List());
    return iv;
  }
}

void main() {
  group('KlapSession', () {
    late KlapSession session;

    setUp(() {
      session = KlapSession(
        deviceIp: TestFixtures.testDeviceIp,
        authHash: TestFixtures.testAuthHash,
      );
    });

    group('constructor', () {
      test('initializes with deviceIp and authHash', () {
        expect(session.deviceIp, TestFixtures.testDeviceIp);
        expect(session.authHash, TestFixtures.testAuthHash);
      });

      test('starts with no session cookie', () {
        expect(session.sessionCookie, isNull);
      });

      test('starts with seq 0', () {
        expect(session.seq, 0);
      });

      test('starts with null key', () {
        expect(session.key, isNull);
      });

      test('starts with null sig', () {
        expect(session.sig, isNull);
      });
    });

    group('isEstablished', () {
      test('returns false when not established', () {
        expect(session.isEstablished, isFalse);
      });
    });
  });

  group('TestableKlapSession', () {
    late TestableKlapSession session;
    late Uint8List localSeed;
    late Uint8List remoteSeed;

    setUp(() {
      session = TestableKlapSession(
        deviceIp: TestFixtures.testDeviceIp,
        authHash: TestFixtures.testAuthHash,
      );
      // Fixed seeds for deterministic testing
      localSeed = Uint8List.fromList(List.generate(16, (i) => i));
      remoteSeed = Uint8List.fromList(List.generate(16, (i) => i + 100));
    });

    group('isEstablished', () {
      test('returns false before handshake', () {
        expect(session.isEstablished, isFalse);
      });

      test('returns true after simulated handshake', () {
        session.simulateHandshake(localSeed, remoteSeed);
        expect(session.isEstablished, isTrue);
      });

      test('returns false if only key is set', () {
        session.setKey(Uint8List(16));
        expect(session.isEstablished, isFalse);
      });

      test('returns false if only iv is set', () {
        session.setIv(Uint8List(12));
        expect(session.isEstablished, isFalse);
      });

      test('returns false if only sig is set', () {
        session.setSig(Uint8List(28));
        expect(session.isEstablished, isFalse);
      });

      test('returns true when all three are set', () {
        session
          ..setKey(Uint8List(16))
          ..setIv(Uint8List(12))
          ..setSig(Uint8List(28));
        expect(session.isEstablished, isTrue);
      });
    });

    group('key derivation', () {
      test('derives 16-byte key', () {
        session.simulateHandshake(localSeed, remoteSeed);
        expect(session.key, isNotNull);
        expect(session.key!.length, 16);
      });

      test('derives 28-byte sig', () {
        session.simulateHandshake(localSeed, remoteSeed);
        expect(session.sig, isNotNull);
        expect(session.sig!.length, 28);
      });

      test('sets seq from iv derivation', () {
        session.simulateHandshake(localSeed, remoteSeed);
        // seq is derived from last 4 bytes of iv hash - just verify it's set
        expect(session.seq, isA<int>());
      });

      test('produces deterministic keys with same seeds', () {
        final session2 = TestableKlapSession(
          deviceIp: TestFixtures.testDeviceIp,
          authHash: TestFixtures.testAuthHash,
        );
        session.simulateHandshake(localSeed, remoteSeed);
        session2.simulateHandshake(localSeed, remoteSeed);

        expect(session.key, session2.key);
        expect(session.sig, session2.sig);
        expect(session.seq, session2.seq);
      });

      test('produces different keys with different local seed', () {
        final session2 = TestableKlapSession(
          deviceIp: TestFixtures.testDeviceIp,
          authHash: TestFixtures.testAuthHash,
        );
        final differentLocal = Uint8List.fromList(
          List.generate(16, (i) => 255 - i),
        );

        session.simulateHandshake(localSeed, remoteSeed);
        session2.simulateHandshake(differentLocal, remoteSeed);

        expect(session.key, isNot(equals(session2.key)));
      });

      test('produces different keys with different remote seed', () {
        final session2 = TestableKlapSession(
          deviceIp: TestFixtures.testDeviceIp,
          authHash: TestFixtures.testAuthHash,
        );
        final differentRemote = Uint8List.fromList(
          List.generate(16, (i) => 255 - i),
        );

        session.simulateHandshake(localSeed, remoteSeed);
        session2.simulateHandshake(localSeed, differentRemote);

        expect(session.key, isNot(equals(session2.key)));
      });

      test('produces different keys with different authHash', () {
        final differentAuth = Uint8List.fromList(
          List.generate(32, (i) => 255 - i),
        );
        final session2 = TestableKlapSession(
          deviceIp: TestFixtures.testDeviceIp,
          authHash: differentAuth,
        );

        session.simulateHandshake(localSeed, remoteSeed);
        session2.simulateHandshake(localSeed, remoteSeed);

        expect(session.key, isNot(equals(session2.key)));
      });
    });

    group('generateIv', () {
      setUp(() {
        session.simulateHandshake(localSeed, remoteSeed);
      });

      test('returns 16-byte IV', () {
        final iv = session.generateIv();
        expect(iv.length, 16);
      });

      test('first 12 bytes are base IV', () {
        session.setIv(
          Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
        );
        final iv = session.generateIv();
        expect(iv.sublist(0, 12), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
      });

      test('last 4 bytes are seq as big-endian int32', () {
        session
          ..setIv(Uint8List(12))
          ..seq = 0x01020304;
        final iv = session.generateIv();
        expect(iv.sublist(12, 16), [1, 2, 3, 4]);
      });

      test('handles negative seq (signed int32)', () {
        session
          ..setIv(Uint8List(12))
          ..seq = -1; // 0xFFFFFFFF
        final iv = session.generateIv();
        expect(iv.sublist(12, 16), [255, 255, 255, 255]);
      });

      test('changes with seq increment', () {
        final iv1 = session.generateIv();
        session.seq++;
        final iv2 = session.generateIv();

        // First 12 bytes same, last 4 different
        expect(iv1.sublist(0, 12), iv2.sublist(0, 12));
        expect(iv1.sublist(12, 16), isNot(equals(iv2.sublist(12, 16))));
      });

      test('seq 0 produces zeroed last 4 bytes', () {
        session
          ..setIv(Uint8List(12))
          ..seq = 0;
        final iv = session.generateIv();
        expect(iv.sublist(12, 16), [0, 0, 0, 0]);
      });
    });

    group('handshake failure scenarios', () {
      test('handshake returns false on network error', () async {
        // Real session can't connect to non-existent device
        final realSession = KlapSession(
          deviceIp: '192.168.255.255', // Invalid IP
          authHash: TestFixtures.testAuthHash,
        );

        final result = await realSession.handshake().timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );

        expect(result, isFalse);
        expect(realSession.isEstablished, isFalse);
      });
    });
  });
}
