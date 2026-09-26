import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/klap_crypto.dart';
import 'package:tapo/services/tapo_service.dart';

import '../helpers/test_utils.dart';

class _KlapSocket extends Fake implements Socket {
  final _sent = <List<int>>[];

  @override
  void add(List<int> data) => _sent.add(data);

  @override
  Future<void> close() async {}

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final remoteSeed = List<int>.filled(16, 1);
    final body = utf8.decode(_sent.first).contains('/handshake1')
        ? <int>[
            ...remoteSeed,
            ...sha256HashBytes([
              ..._sent.last,
              ...remoteSeed,
              ...TestFixtures.testAuthHash,
            ]),
          ]
        : <int>[];
    return Stream.value(
      Uint8List.fromList([
        ...utf8.encode(
          'HTTP/1.1 200 OK\r\n'
          'Content-Length: ${body.length}\r\n'
          'Set-Cookie: TP_SESSIONID=test\r\n\r\n',
        ),
        ...body,
      ]),
    ).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _UnavailableTpapClient extends Fake implements HttpClient {
  @override
  set connectionTimeout(Duration? value) {}

  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? callback,
  ) {}

  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      throw const SocketException('TPAP unavailable');

  @override
  void close({bool force = false}) {}
}

void main() {
  test('reconnects with KLAP after starting without Wi-Fi', () async {
    var wifiAvailable = false;
    final service = TapoService.fromCredentials(
      TestFixtures.testEmail,
      TestFixtures.testPassword,
    );
    addTearDown(service.disconnectAll);

    await IOOverrides.runZoned(
      () => HttpOverrides.runZoned(() async {
        expect(
          await service.connectToDevice(TestFixtures.testDeviceIp),
          isFalse,
        );

        wifiAvailable = true;

        expect(
          await service.connectToDevice(TestFixtures.testDeviceIp),
          isTrue,
        );
      }, createHttpClient: (_) => _UnavailableTpapClient()),
      socketConnect:
          (host, port, {sourceAddress, sourcePort = 0, timeout}) async {
            if (!wifiAvailable) {
              throw const SocketException('Wi-Fi unavailable');
            }
            return _KlapSocket();
          },
    );
  });
}
