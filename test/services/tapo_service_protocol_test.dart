import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:tapo/core/http_utils.dart';
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

final Matcher _isOnline = isA<TapoDevice>().having(
  (d) => d.isOnline,
  'isOnline',
  isTrue,
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

final _protocols = <String, LoginPlug Function()>{
  'KLAP': FakeKlapPlug.new,
  'TPAP': FakeTpapPlugWithLogin.new,
};

T? _runAgainst<T>(LoginPlug plug, Future<T> Function() action) =>
    switch (plug) {
      final FakeKlapPlug klap => runAgainstPlugs(action, klap: klap),
      final FakeTpapPlug tpap => runAgainstPlugs(action, tpap: tpap),
      _ => throw ArgumentError.value(plug, 'plug'),
    };

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

      final states = runAgainstPlugs(
        () async {
          final connected = await service.getDeviceState(_ip);
          plug.port = PortState.dropped;
          return [connected, await service.getDeviceState(_ip)];
        },
        klap: plug,
        // A single timeout: a plug that does not answer is not logged in to
        // again.
        elapse: deviceTimeout + const Duration(seconds: 1),
      );

      expect(states?.map((d) => d.isOnline), [true, false]);
    });

    test('when it never answers a TPAP request', () {
      final tpap = FakeTpapPlugWithLogin()
        ..onRequest = (_) => const SilentReply();

      final device = runAgainstPlugs(
        () => _service().getDeviceState(_ip),
        tpap: tpap,
      );

      expect(device, _isOffline);
      expect(tpap.allRequestsFinished, isTrue);
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

  for (final MapEntry(key: protocol, value: newPlug) in _protocols.entries) {
    group('over $protocol, logs in again', () {
      test('when another app took over before reading the state', () {
        final plug = newPlug()..onRequest = _plugOff;
        final service = _service();

        final device = _runAgainst(plug, () async {
          await service.getDeviceState(_ip);
          plug.logInFromAnotherApp();
          return await service.getDeviceState(_ip);
        });

        expect(device, _isOnline);
      });

      test('when another app took over between reading and switching', () {
        final plug = newPlug();
        var tookOver = false;
        plug.onRequest = (request) {
          if (request['method'] == 'set_device_info') {
            return const JsonReply({'error_code': 0});
          }
          if (!tookOver) {
            tookOver = true;
            plug.logInFromAnotherApp();
          }
          return _plugOff(request);
        };

        final device = _runAgainst(plug, () => _service().toggleDevice(_ip));

        expect(device, _isOnline);
        expect(device?.deviceOn, isTrue);
      });

      test('when the plug reports in its reply that the session expired', () {
        final plug = newPlug();
        var expired = false;
        plug.onRequest = (request) {
          if (expired) return _plugOff(request);
          expired = true;
          return const JsonReply({'error_code': 9999});
        };

        final device = _runAgainst(plug, () => _service().getDeviceState(_ip));

        expect(device, _isOnline);
      });

      test('once for callers refused at the same time', () {
        final plug = newPlug()..onRequest = _plugOff;
        final service = _service();

        final devices = _runAgainst(plug, () async {
          await service.getDeviceState(_ip);
          plug.logInFromAnotherApp();
          // A tray refresh while the user toggles the plug.
          return await Future.wait([
            service.getDeviceState(_ip),
            service.toggleDevice(_ip),
          ]);
        });

        expect(devices, [_isOnline, _isOnline]);
        expect(devices?.last.deviceOn, isTrue);
      });
    });

    test('over $protocol, does not switch a plug disconnected meanwhile', () {
      final plug = newPlug();
      final service = _service();
      final methods = <Object?>[];
      plug.onRequest = (request) {
        methods.add(request['method']);
        // The user removes the plug while its state is read.
        unawaited(service.disconnect(_ip));
        return _plugOff(request);
      };

      _runAgainst(plug, () => service.toggleDevice(_ip));

      expect(methods, ['get_device_info']);
    });
  }

  test('does not log in again to a busy TPAP plug', () {
    final tpap = FakeTpapPlugWithLogin()
      ..onRequest = (_) => const StatusReply(HttpStatus.serviceUnavailable);

    final device = runAgainstPlugs(
      () => _service().getDeviceState(_ip),
      tpap: tpap,
    );

    expect(device, _isOffline);
    expect(tpap.appLogins, 1);
  });

  test('lets a TPAP command finish when a refresh gives up on the plug', () {
    final tpap = FakeTpapPlugWithLogin();
    var reads = 0;
    tpap.onRequest = (request) => switch (request['method']) {
      'set_device_info' => const DelayedReply(
        Duration(seconds: 7),
        JsonReply({'error_code': 0}),
      ),
      // The refresh: the plug misses it.
      _ when reads++ == 1 => const SilentReply(),
      _ => _plugOff(request),
    };
    final service = _service();

    final device = runAgainstPlugs(() async {
      await service.getDeviceState(_ip);
      final refresh = service.getDeviceState(_ip);
      // The refresh times out while the plug switches.
      await Future<void>.delayed(const Duration(seconds: 5));
      final toggled = await service.toggleDevice(_ip);
      await refresh;
      return toggled;
    }, tpap: tpap);

    expect(device, _isOnline);
    expect(device?.deviceOn, isTrue);
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

    test('reports the plug offline when it resets the connection', () {
      final plug = FakeKlapPlug()..onRequest = (_) => const ResetReply();

      final device = runAgainstPlugs(
        () => _service().getDeviceState(_ip),
        klap: plug,
      );

      expect(device, _isOffline);
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
