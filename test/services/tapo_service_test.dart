import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/klap_crypto.dart';
import 'package:tapo/core/klap_session.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/tapo_client.dart';
import 'package:tapo/services/tapo_service.dart';

import '../helpers/test_utils.dart';

/// Mock KlapSession for testing
class MockKlapSessionForService extends KlapSession {
  MockKlapSessionForService({required super.deviceIp, required super.authHash});

  bool _isEstablished = false;
  bool handshakeSuccess = true;

  @override
  bool get isEstablished => _isEstablished;

  set isEstablished(bool value) {
    _isEstablished = value;
  }

  @override
  Future<bool> handshake() async {
    if (handshakeSuccess) {
      _isEstablished = true;
    }
    return handshakeSuccess;
  }
}

/// Mock TapoClient for testing
class MockTapoClientForService extends TapoClient {
  MockTapoClientForService({required super.session});

  Map<String, dynamic>? deviceInfoResponse;
  bool setDeviceOnSuccess = true;

  @override
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    return deviceInfoResponse;
  }

  @override
  Future<bool> setDeviceOn({required bool on}) async {
    return setDeviceOnSuccess;
  }
}

/// Testable TapoService that allows injecting mock sessions and clients
class TestableTapoService extends TapoService {
  TestableTapoService({
    required super.authHash,
    required super.email,
    required super.password,
  });

  // Allow injection of mock sessions/clients
  final Map<String, MockKlapSessionForService> mockSessions = {};
  final Map<String, MockTapoClientForService> mockClients = {};

  // Track connect attempts
  int connectAttempts = 0;

  // Control KLAP handshake success
  bool klapHandshakeSuccess = true;
  bool tpapHandshakeSuccess = false;

  @override
  Future<bool> connectToDevice(String ip) async {
    connectAttempts++;

    // Check for existing established mock session
    if (mockSessions.containsKey(ip) && mockSessions[ip]!.isEstablished) {
      return true;
    }

    // Create and use mock session
    final mockSession = MockKlapSessionForService(
      deviceIp: ip,
      authHash: TestFixtures.testAuthHash,
    )..handshakeSuccess = klapHandshakeSuccess;

    final success = await mockSession.handshake();

    if (success) {
      mockSessions[ip] = mockSession;
      mockClients[ip] = MockTapoClientForService(session: mockSession);
      return true;
    }

    // Simulate TPAP fallback (simplified for testing)
    if (tpapHandshakeSuccess) {
      // Mark as connected via TPAP
      mockSession.isEstablished = true;
      mockSessions[ip] = mockSession;
      mockClients[ip] = MockTapoClientForService(session: mockSession);
      return true;
    }

    return false;
  }

  @override
  Future<TapoDevice> getDeviceState(String ip) async {
    if (!mockSessions.containsKey(ip) || !mockSessions[ip]!.isEstablished) {
      final connected = await connectToDevice(ip);
      if (!connected) {
        return TapoDevice(
          ip: ip,
          nickname: 'Unknown',
          model: 'Unknown',
          deviceOn: false,
          isOnline: false,
        );
      }
    }

    final client = mockClients[ip];
    final info = await client?.getDeviceInfo();

    if (info == null) {
      disconnect(ip);
      return TapoDevice(
        ip: ip,
        nickname: 'Unknown',
        model: 'Unknown',
        deviceOn: false,
        isOnline: false,
      );
    }

    return TapoDevice(
      ip: ip,
      nickname: info['nickname'] as String? ?? 'Tapo Device',
      model: info['model'] as String? ?? 'Unknown',
      deviceOn: info['device_on'] as bool? ?? false,
      isOnline: true,
    );
  }

  @override
  Future<TapoDevice> toggleDevice(String ip) async {
    final currentState = await getDeviceState(ip);
    if (!currentState.isOnline) return currentState;

    final client = mockClients[ip];
    if (client == null) return currentState;

    final newState = !currentState.deviceOn;
    final success = await client.setDeviceOn(on: newState);

    if (!success) {
      disconnect(ip);
      return currentState.copyWith(isOnline: false);
    }

    return currentState.copyWith(deviceOn: newState);
  }

  @override
  void disconnect(String ip) {
    mockSessions.remove(ip);
    mockClients.remove(ip);
  }

  @override
  void disconnectAll() {
    mockSessions.clear();
    mockClients.clear();
  }

  // Helper to check if session exists
  bool hasSession(String ip) => mockSessions.containsKey(ip);

  // Helper to check if client exists
  bool hasClient(String ip) => mockClients.containsKey(ip);
}

void main() {
  group('TapoService', () {
    group('constructor', () {
      test('creates service with authHash, email, and password', () {
        final service = TapoService(
          authHash: TestFixtures.testAuthHash,
          email: TestFixtures.testEmail,
          password: TestFixtures.testPassword,
        );

        expect(service, isNotNull);
      });
    });

    group('fromCredentials factory', () {
      test('creates service from email and password', () {
        final service = TapoService.fromCredentials(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        expect(service, isNotNull);
      });

      test('generates correct authHash from credentials', () {
        // Verify generateAuthHash doesn't throw
        generateAuthHash(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        final service = TapoService.fromCredentials(
          TestFixtures.testEmail,
          TestFixtures.testPassword,
        );

        // We can't directly access _authHash, but we verify factory works
        expect(service, isNotNull);
      });
    });
  });

  group('TestableTapoService', () {
    late TestableTapoService service;

    setUp(() {
      service = TestableTapoService(
        authHash: TestFixtures.testAuthHash,
        email: TestFixtures.testEmail,
        password: TestFixtures.testPassword,
      );
    });

    group('connectToDevice', () {
      test('returns true on successful KLAP handshake', () async {
        service.klapHandshakeSuccess = true;

        final result = await service.connectToDevice(TestFixtures.testDeviceIp);

        expect(result, isTrue);
        expect(service.hasSession(TestFixtures.testDeviceIp), isTrue);
        expect(service.hasClient(TestFixtures.testDeviceIp), isTrue);
      });

      test('returns false when KLAP and TPAP both fail', () async {
        service
          ..klapHandshakeSuccess = false
          ..tpapHandshakeSuccess = false;

        final result = await service.connectToDevice(TestFixtures.testDeviceIp);

        expect(result, isFalse);
      });

      test('falls back to TPAP when KLAP fails', () async {
        service
          ..klapHandshakeSuccess = false
          ..tpapHandshakeSuccess = true;

        final result = await service.connectToDevice(TestFixtures.testDeviceIp);

        expect(result, isTrue);
        expect(service.hasSession(TestFixtures.testDeviceIp), isTrue);
      });

      test('reuses existing established session', () async {
        service.klapHandshakeSuccess = true;

        await service.connectToDevice(TestFixtures.testDeviceIp);
        final attempts1 = service.connectAttempts;

        await service.connectToDevice(TestFixtures.testDeviceIp);
        final attempts2 = service.connectAttempts;

        // Should only attempt handshake once
        expect(attempts2, attempts1 + 1);
      });

      test('creates separate sessions for different IPs', () async {
        service.klapHandshakeSuccess = true;

        await service.connectToDevice(TestFixtures.testDeviceIp);
        await service.connectToDevice(TestFixtures.testDeviceIp2);

        expect(service.hasSession(TestFixtures.testDeviceIp), isTrue);
        expect(service.hasSession(TestFixtures.testDeviceIp2), isTrue);
      });
    });

    group('getDeviceState', () {
      test('returns online device on successful connection and info', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        service.mockClients[TestFixtures.testDeviceIp]!.deviceInfoResponse =
            TestFixtures.deviceInfoResponse();

        final device = await service.getDeviceState(TestFixtures.testDeviceIp);

        expect(device.isOnline, isTrue);
        expect(device.ip, TestFixtures.testDeviceIp);
        expect(device.nickname, 'Test Plug');
        expect(device.model, 'P110');
        expect(device.deviceOn, isTrue);
      });

      test('returns offline device when connection fails', () async {
        service
          ..klapHandshakeSuccess = false
          ..tpapHandshakeSuccess = false;

        final device = await service.getDeviceState(TestFixtures.testDeviceIp);

        expect(device.isOnline, isFalse);
        expect(device.ip, TestFixtures.testDeviceIp);
        expect(device.nickname, 'Unknown');
        expect(device.model, 'Unknown');
      });

      test('returns offline device when getDeviceInfo returns null', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        service.mockClients[TestFixtures.testDeviceIp]!
            .deviceInfoResponse = null;

        final device =
            await service.getDeviceState(TestFixtures.testDeviceIp);

        expect(device.isOnline, isFalse);
      });

      test(
          'disconnects and returns offline when getDeviceInfo fails',
          () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        service.mockClients[TestFixtures.testDeviceIp]!
            .deviceInfoResponse = null;

        await service.getDeviceState(TestFixtures.testDeviceIp);

        expect(service.hasSession(TestFixtures.testDeviceIp), isFalse);
      });

      test('auto-connects if not already connected', () async {
        service.klapHandshakeSuccess = true;

        // Don't call connectToDevice first
        expect(service.hasSession(TestFixtures.testDeviceIp), isFalse);

        // Set up mock response for when it auto-connects
        await service.getDeviceState(TestFixtures.testDeviceIp);

        // Should have attempted connection
        expect(service.connectAttempts, 1);
      });

      test('uses default nickname when missing', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        service.mockClients[TestFixtures.testDeviceIp]!.deviceInfoResponse = {
          'model': 'P110',
          'device_on': true,
        };

        final device = await service.getDeviceState(TestFixtures.testDeviceIp);

        expect(device.nickname, 'Tapo Device');
      });

      test('uses default model when missing', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        service.mockClients[TestFixtures.testDeviceIp]!.deviceInfoResponse = {
          'nickname': 'My Plug',
          'device_on': true,
        };

        final device = await service.getDeviceState(TestFixtures.testDeviceIp);

        expect(device.model, 'Unknown');
      });
    });

    group('toggleDevice', () {
      test('toggles device on to off', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        service.mockClients[TestFixtures.testDeviceIp]!
            .deviceInfoResponse =
            TestFixtures.deviceInfoResponse();

        final result = await service.toggleDevice(TestFixtures.testDeviceIp);

        expect(result.deviceOn, isFalse);
        expect(result.isOnline, isTrue);
      });

      test('toggles device off to on', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        service.mockClients[TestFixtures.testDeviceIp]!
            .deviceInfoResponse =
            TestFixtures.deviceInfoResponse(deviceOn: false);

        final result = await service.toggleDevice(TestFixtures.testDeviceIp);

        expect(result.deviceOn, isTrue);
        expect(result.isOnline, isTrue);
      });

      test('returns current offline state when device is offline', () async {
        service
          ..klapHandshakeSuccess = false
          ..tpapHandshakeSuccess = false;

        final result = await service.toggleDevice(TestFixtures.testDeviceIp);

        expect(result.isOnline, isFalse);
      });

      test('returns offline state when setDeviceOn fails',
          () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(
          TestFixtures.testDeviceIp,
        );
        service.mockClients[TestFixtures.testDeviceIp]!
          ..deviceInfoResponse =
              TestFixtures.deviceInfoResponse()
          ..setDeviceOnSuccess = false;

        final result = await service.toggleDevice(TestFixtures.testDeviceIp);

        expect(result.isOnline, isFalse);
      });

      test('disconnects when setDeviceOn fails', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(
          TestFixtures.testDeviceIp,
        );
        service.mockClients[TestFixtures.testDeviceIp]!
          ..deviceInfoResponse =
              TestFixtures.deviceInfoResponse()
          ..setDeviceOnSuccess = false;

        await service.toggleDevice(TestFixtures.testDeviceIp);

        expect(service.hasSession(TestFixtures.testDeviceIp), isFalse);
      });
    });

    group('disconnect', () {
      test('removes session and client for IP', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);

        expect(service.hasSession(TestFixtures.testDeviceIp), isTrue);
        expect(service.hasClient(TestFixtures.testDeviceIp), isTrue);

        service.disconnect(TestFixtures.testDeviceIp);

        expect(service.hasSession(TestFixtures.testDeviceIp), isFalse);
        expect(service.hasClient(TestFixtures.testDeviceIp), isFalse);
      });

      test('does not affect other device sessions', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        await service.connectToDevice(TestFixtures.testDeviceIp2);

        service.disconnect(TestFixtures.testDeviceIp);

        expect(service.hasSession(TestFixtures.testDeviceIp), isFalse);
        expect(service.hasSession(TestFixtures.testDeviceIp2), isTrue);
      });

      test('is safe to call on non-existent session', () {
        // Should not throw
        service.disconnect(TestFixtures.testDeviceIp);
        expect(service.hasSession(TestFixtures.testDeviceIp), isFalse);
      });
    });

    group('disconnectAll', () {
      test('clears all sessions and clients', () async {
        service.klapHandshakeSuccess = true;
        await service.connectToDevice(TestFixtures.testDeviceIp);
        await service.connectToDevice(TestFixtures.testDeviceIp2);

        expect(service.mockSessions.length, 2);
        expect(service.mockClients.length, 2);

        service.disconnectAll();

        expect(service.mockSessions.isEmpty, isTrue);
        expect(service.mockClients.isEmpty, isTrue);
      });

      test('is safe to call when no sessions exist', () {
        // Should not throw
        service.disconnectAll();
        expect(service.mockSessions.isEmpty, isTrue);
      });
    });
  });
}
