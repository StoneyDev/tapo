import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/tpap_session.dart';

void main() {
  group('TpapCredentials', () {
    test('stores email and password', () {
      final creds = TpapCredentials(
        email: 'user@example.com',
        password: 'secret123',
      );

      expect(creds.email, 'user@example.com');
      expect(creds.password, 'secret123');
    });
  });

  group('TpapSession', () {
    test('stores deviceIp and credentials', () {
      final creds = TpapCredentials(
        email: 'user@example.com',
        password: 'password',
      );
      final session = TpapSession(
        deviceIp: '192.168.1.100',
        credentials: creds,
      );

      expect(session.deviceIp, '192.168.1.100');
      expect(session.credentials.email, 'user@example.com');
    });

    test('isEstablished is false initially', () {
      final session = TpapSession(
        deviceIp: '192.168.1.100',
        credentials: TpapCredentials(
          email: 'test@test.com',
          password: 'pass',
        ),
      );

      expect(session.isEstablished, isFalse);
    });

    test('request returns null when not established', () async {
      final session = TpapSession(
        deviceIp: '192.168.1.100',
        credentials: TpapCredentials(
          email: 'test@test.com',
          password: 'pass',
        ),
      );

      final result = await session.request({'method': 'get_device_info'});
      expect(result, isNull);
    });

    test('close can be called safely when not connected', () async {
      final session = TpapSession(
        deviceIp: '192.168.1.100',
        credentials: TpapCredentials(
          email: 'test@test.com',
          password: 'pass',
        ),
      );

      // Should not throw
      await session.close();
      expect(session.isEstablished, isFalse);
    });

    // Note: handshake, probeDevice, testTlsConnection require actual network
    // connections. These would need integration tests or extensive mocking
    // of HttpClient which is complex in Dart.
  });
}
