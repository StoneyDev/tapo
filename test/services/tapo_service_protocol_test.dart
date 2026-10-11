import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/tapo_service.dart';

import '../helpers/fake_plugs.dart';
import '../helpers/test_utils.dart';

const String _ip = TestFixtures.testDeviceIp;

final Matcher _isOffline = isA<TapoDevice>().having(
  (d) => d.isOnline,
  'isOnline',
  isFalse,
);

/// A KLAP request whose ciphertext is not a whole AES block.
final RawReply _malformedReply = RawReply([...List.filled(32, 0), 1]);

TapoService _service() {
  final service = TapoService.fromCredentials(
    TestFixtures.testEmail,
    TestFixtures.testPassword,
  );
  addTearDown(service.disconnectAll);
  return service;
}

PlugReply _plugOff(Map<String, dynamic> request) => const JsonReply({
  'error_code': 0,
  'result': {'nickname': 'Desk', 'model': 'P110', 'device_on': false},
});

void main() {
  test('reconnects with KLAP after starting without Wi-Fi', () {
    final plug = FakeKlapPlug()..port = PortState.refused;
    final service = _service();

    final results = runAgainstPlugs(() async {
      final withoutWifi = await service.connectToDevice(_ip);
      plug.port = PortState.open;
      return [withoutWifi, await service.connectToDevice(_ip)];
    }, klap: plug);

    expect(results, [false, true]);
  });

  group('reports a plug offline instead of waiting forever', () {
    test('when it never answers the KLAP handshake', () {
      final plug = FakeKlapPlug()..handshake1 = const SilentReply();

      final device = runAgainstPlugs(
        () => _service().getDeviceState(_ip),
        klap: plug,
      );

      expect(device, _isOffline);
    });

    test('when it drops off the network after connecting', () {
      final plug = FakeKlapPlug()..onRequest = _plugOff;
      final service = _service();

      final states = runAgainstPlugs(() async {
        final connected = await service.getDeviceState(_ip);
        plug.port = PortState.dropped;
        return [connected, await service.getDeviceState(_ip)];
      }, klap: plug);

      expect(states?.map((d) => d.isOnline), [true, false]);
    });

    test('when it never answers the TPAP handshake', () {
      final tpap = FakeTpapPlug()..onPost = (_, _) => const SilentReply();

      final device = runAgainstPlugs(
        () => _service().getDeviceState(_ip),
        tpap: tpap,
      );

      expect(device, _isOffline);
    });
  });

  test('gives each TPAP handshake step its own timeout', () {
    // Each answer takes 6 s: together they exceed a single 10 s budget.
    final tpap = FakeTpapPlug()
      ..onPost = (url, _) => DelayedReply(
        const Duration(seconds: 6),
        switch (url.path) {
          '/app' => JsonReply({
            'result': {
              'salt': base64Encode(List.filled(16, 7)),
              'iterations': 1000,
              'transaction_id': 'tx',
            },
          }),
          '/app/handshake2' => JsonReply({
            'result': {
              'server_share': base64Encode(ECCurve_secp256r1().G.getEncoded()),
              'transaction_id': 'tx',
            },
          }),
          _ => const HangUpReply(),
        },
      );

    runAgainstPlugs(() => _service().getDeviceState(_ip), tpap: tpap);

    expect(tpap.requests.map((url) => url.path), contains('/app/handshake3'));
  });

  test('tries TPAP with a single request when the plug refuses it', () {
    final tpap = FakeTpapPlug();

    runAgainstPlugs(() => _service().getDeviceState(_ip), tpap: tpap);

    expect(tpap.requests, hasLength(1));
  });

  group('survives malformed data from a plug', () {
    test('falls back to TPAP when KLAP hangs up without answering', () {
      final plug = FakeKlapPlug()..handshake1 = const HangUpReply();
      final tpap = FakeTpapPlug();

      final device = runAgainstPlugs(
        () => _service().getDeviceState(_ip),
        klap: plug,
        tpap: tpap,
      );

      expect(device, _isOffline);
      expect(tpap.requests, isNotEmpty);
    });

    test('reports the plug offline when its state reply is malformed', () {
      final plug = FakeKlapPlug()..onRequest = (_) => _malformedReply;

      final device = runAgainstPlugs(
        () => _service().getDeviceState(_ip),
        klap: plug,
      );

      expect(device, _isOffline);
    });

    test('releases the socket when the plug hangs up on a request', () {
      final plug = FakeKlapPlug()..onRequest = (_) => const HangUpReply();

      final device = runAgainstPlugs(
        () => _service().getDeviceState(_ip),
        klap: plug,
      );

      expect(device, _isOffline);
      expect(plug.allSocketsReleased, isTrue);
    });

    test('reports the plug offline when its toggle reply is malformed', () {
      final plug = FakeKlapPlug()
        ..onRequest = (request) => request['method'] == 'set_device_info'
            ? _malformedReply
            : _plugOff(request);

      final device = runAgainstPlugs(
        () => _service().toggleDevice(_ip),
        klap: plug,
      );

      expect(device, _isOffline);
    });

    test('closes the TPAP connection when the handshake is malformed', () {
      final tpap = FakeTpapPlug()
        ..onPost = (_, _) => RawReply(utf8.encode('[]'));

      final device = runAgainstPlugs(
        () => _service().getDeviceState(_ip),
        tpap: tpap,
      );

      expect(device, _isOffline);
      expect(tpap.allClientsClosed, isTrue);
    });
  });

  group('PBKDF2 iterations requested by a TPAP plug', () {
    for (final (iterations, derivesPassword) in [
      (100000, true),
      (100001, false),
    ]) {
      test('$iterations ${derivesPassword ? 'are' : 'are not'} accepted', () {
        final tpap = FakeTpapPlug()
          ..onPost = (url, _) => url.path == '/app'
              ? JsonReply({
                  'result': {
                    'salt': base64Encode(List.filled(16, 7)),
                    'iterations': iterations,
                    'transaction_id': 'tx',
                  },
                })
              : const HangUpReply();

        runAgainstPlugs(() => _service().getDeviceState(_ip), tpap: tpap);

        expect(
          tpap.requests.map((url) => url.path),
          derivesPassword
              ? contains('/app/handshake2')
              : isNot(contains('/app/handshake2')),
        );
      });
    }
  });
}
