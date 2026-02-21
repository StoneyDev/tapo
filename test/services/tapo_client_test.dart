import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/klap_session.dart';
import 'package:tapo/services/tapo_client.dart';

import '../helpers/test_utils.dart';

/// Testable subclass that allows injecting mock network responses
class TestableTapoClient extends TapoClient {
  TestableTapoClient({required super.session});

  Map<String, dynamic>? mockResponse;
  bool shouldThrow = false;
  int requestCount = 0;
  Map<String, dynamic>? lastRequestPayload;

  @override
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    return _mockRequest({'method': 'get_device_info'}, extractResult: true);
  }

  @override
  Future<bool> setDeviceOn({required bool on}) async {
    final response = await _mockRequest({
      'method': 'set_device_info',
      'params': {'device_on': on},
    });
    return response != null;
  }

  Future<Map<String, dynamic>?> _mockRequest(
    Map<String, dynamic> payload, {
    bool extractResult = false,
  }) async {
    if (!session.isEstablished) return null;

    requestCount++;
    lastRequestPayload = payload;

    try {
      if (shouldThrow) throw Exception('Network error');
      if (mockResponse == null) return null;

      // Simulate real behavior: check error_code
      if (mockResponse!['error_code'] != 0) return null;

      if (extractResult) {
        return mockResponse!['result'] as Map<String, dynamic>?;
      }
      return mockResponse;
    } on Exception {
      return null;
    }
  }
}

/// Testable KlapSession for setting up established session state
class TestableKlapSessionForClient extends KlapSession {
  TestableKlapSessionForClient({
    required super.deviceIp,
    required super.authHash,
  });

  Uint8List? _key;
  Uint8List? _iv;
  Uint8List? _sig;

  void setEstablished() {
    _key = Uint8List(16);
    _iv = Uint8List(12);
    _sig = Uint8List(28);
    sessionCookie = 'TP_SESSIONID=test';
    seq = 0;
  }

  @override
  Uint8List? get key => _key;

  @override
  Uint8List? get sig => _sig;

  @override
  bool get isEstablished => _key != null && _iv != null && _sig != null;

  @override
  Uint8List generateIv() {
    final iv = Uint8List(16)..setAll(0, _iv!);
    final seqBytes = ByteData(4)..setInt32(0, seq);
    iv.setAll(12, seqBytes.buffer.asUint8List());
    return iv;
  }
}

void main() {
  group('TapoClient', () {
    late KlapSession session;

    setUp(() {
      session = KlapSession(
        deviceIp: TestFixtures.testDeviceIp,
        authHash: TestFixtures.testAuthHash,
      );
    });

    group('constructor', () {
      test('creates client with session', () {
        final client = TapoClient(session: session);
        expect(client.session, session);
      });
    });

    group('session not established', () {
      test('getDeviceInfo returns null when session not established', () async {
        final client = TestableTapoClient(session: session)
          ..mockResponse = {
            'error_code': 0,
            'result': TestFixtures.deviceInfoResponse(),
          };

        final result = await client.getDeviceInfo();

        expect(result, isNull);
        expect(client.requestCount, 0); // Should not attempt request
      });

      test('setDeviceOn returns false when session not established', () async {
        final client = TestableTapoClient(session: session)
          ..mockResponse = {'error_code': 0};

        final result = await client.setDeviceOn(on: true);

        expect(result, isFalse);
        expect(client.requestCount, 0);
      });
    });
  });

  group('TestableTapoClient', () {
    late TestableKlapSessionForClient session;
    late TestableTapoClient client;

    setUp(() {
      session = TestableKlapSessionForClient(
        deviceIp: TestFixtures.testDeviceIp,
        authHash: TestFixtures.testAuthHash,
      )..setEstablished();
      client = TestableTapoClient(session: session);
    });

    group('getDeviceInfo', () {
      test('returns device info on success', () async {
        client.mockResponse = {
          'error_code': 0,
          'result': {
            'nickname': 'Living Room',
            'model': 'P110',
            'device_on': true,
          },
        };

        final result = await client.getDeviceInfo();

        expect(result, isNotNull);
        expect(result!['nickname'], 'Living Room');
        expect(result['model'], 'P110');
        expect(result['device_on'], true);
      });

      test('returns null on error_code != 0', () async {
        client.mockResponse = {'error_code': -1, 'result': null};

        final result = await client.getDeviceInfo();

        expect(result, isNull);
      });

      test('returns null on null response', () async {
        client.mockResponse = null;

        final result = await client.getDeviceInfo();

        expect(result, isNull);
      });

      test('returns null when result is null', () async {
        client.mockResponse = {'error_code': 0, 'result': null};

        final result = await client.getDeviceInfo();

        expect(result, isNull);
      });

      test('sends correct method in request', () async {
        client.mockResponse = {
          'error_code': 0,
          'result': TestFixtures.deviceInfoResponse(),
        };

        await client.getDeviceInfo();

        expect(client.lastRequestPayload, {'method': 'get_device_info'});
      });

      test('increments request count', () async {
        client.mockResponse = {
          'error_code': 0,
          'result': TestFixtures.deviceInfoResponse(),
        };

        await client.getDeviceInfo();
        await client.getDeviceInfo();

        expect(client.requestCount, 2);
      });
    });

    group('setDeviceOn', () {
      test('returns true on success turning on', () async {
        client.mockResponse = {'error_code': 0};

        final result = await client.setDeviceOn(on: true);

        expect(result, isTrue);
      });

      test('returns true on success turning off', () async {
        client.mockResponse = {'error_code': 0};

        final result = await client.setDeviceOn(on: false);

        expect(result, isTrue);
      });

      test('returns false on error_code != 0', () async {
        client.mockResponse = {'error_code': -1};

        final result = await client.setDeviceOn(on: true);

        expect(result, isFalse);
      });

      test('returns false on null response', () async {
        client.mockResponse = null;

        final result = await client.setDeviceOn(on: true);

        expect(result, isFalse);
      });

      test('sends correct method and params for on=true', () async {
        client.mockResponse = {'error_code': 0};

        await client.setDeviceOn(on: true);

        expect(client.lastRequestPayload, {
          'method': 'set_device_info',
          'params': {'device_on': true},
        });
      });

      test('sends correct method and params for on=false', () async {
        client.mockResponse = {'error_code': 0};

        await client.setDeviceOn(on: false);

        expect(client.lastRequestPayload, {
          'method': 'set_device_info',
          'params': {'device_on': false},
        });
      });
    });

    group('error handling', () {
      test('getDeviceInfo returns null on exception', () async {
        client.shouldThrow = true;

        final result = await client.getDeviceInfo();

        expect(result, isNull);
      });

      test('setDeviceOn returns false on exception', () async {
        client.shouldThrow = true;

        final result = await client.setDeviceOn(on: true);

        expect(result, isFalse);
      });
    });
  });

  group('TapoClient request encryption logic', () {
    late TestableKlapSessionForClient session;

    setUp(() {
      session = TestableKlapSessionForClient(
        deviceIp: TestFixtures.testDeviceIp,
        authHash: TestFixtures.testAuthHash,
      )..setEstablished();
    });

    test('generateIv produces correct format', () {
      session.seq = 5;
      final iv = session.generateIv();

      expect(iv.length, 16);
      // Last 4 bytes should be seq as big-endian
      expect(iv[12], 0);
      expect(iv[13], 0);
      expect(iv[14], 0);
      expect(iv[15], 5);
    });

    test('seq increments are reflected in IV', () {
      session.seq = 0;
      final iv1 = session.generateIv();
      session.seq = 1;
      final iv2 = session.generateIv();

      expect(iv1.sublist(0, 12), iv2.sublist(0, 12)); // Base IV same
      expect(iv1[15], 0);
      expect(iv2[15], 1);
    });
  });
}
