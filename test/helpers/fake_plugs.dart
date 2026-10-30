import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/core/klap_crypto.dart';
import 'package:jolt/core/tpap_crypto.dart';
import 'package:pointycastle/export.dart';

import 'test_utils.dart';

/// Runs [action] in fake time against [klap] (raw sockets) and [tpap]
/// (HttpClient), letting [elapse] pass. Returns null if [action] has not
/// completed by then; an error thrown by [action] fails the test.
T? runAgainstPlugs<T>(
  Future<T> Function() action, {
  FakeKlapPlug? klap,
  FakeTpapPlug? tpap,
  Duration elapse = const Duration(minutes: 5),
}) {
  final klapPlug = klap ?? (FakeKlapPlug()..port = PortState.refused);
  final tpapPlug = tpap ?? FakeTpapPlug();
  T? result;
  fakeAsync((async) {
    IOOverrides.runZoned(
      () => HttpOverrides.runZoned(
        () => unawaited(action().then((value) => result = value)),
        createHttpClient: tpapPlug.createClient,
      ),
      socketConnect: (host, port, {sourceAddress, sourcePort = 0, timeout}) =>
          klapPlug.connect(timeout),
    );
    async.elapse(elapse);
  });
  return result;
}

/// How a fake plug's port reacts to a new connection.
enum PortState {
  open,

  /// Fails at once, like a closed port or a network that is down.
  refused,

  /// Drops packets: connecting only fails when the caller's timeout expires.
  dropped,
}

/// What a fake plug sends back for one exchange.
sealed class PlugReply {
  const PlugReply();
}

/// Accepts the request and never answers.
class SilentReply extends PlugReply {
  const SilentReply();
}

/// Closes the connection without sending anything.
class HangUpReply extends PlugReply {
  const HangUpReply();
}

/// Resets the connection: reading and writing both fail.
class ResetReply extends PlugReply {
  const ResetReply();
}

/// Answers [statusCode] with no body; a plug answers 403 for a session it no
/// longer has.
class StatusReply extends PlugReply {
  const StatusReply(this.statusCode);

  final int statusCode;
}

/// Answers 200 with [bytes] as the body, unencrypted.
class RawReply extends PlugReply {
  const RawReply(this.bytes);

  final List<int> bytes;
}

/// Answers 200 with [payload], encrypted by KLAP plugs.
class JsonReply extends PlugReply {
  const JsonReply(this.payload);

  final Object payload;
}

/// Sends [reply] after [delay]; TPAP plugs only.
class DelayedReply extends PlugReply {
  const DelayedReply(this.delay, this.reply);

  final Duration delay;
  final PlugReply reply;
}

/// A plug the app logs in to, whatever its protocol.
abstract interface class LoginPlug {
  /// Answers a decrypted `/app/request`.
  PlugReply Function(Map<String, dynamic> request) get onRequest;
  set onRequest(PlugReply Function(Map<String, dynamic> request) answer);

  /// Another app logs in to the plug, which drops the app's session.
  void logInFromAnotherApp();
}

/// A plug speaking KLAP on port 80, reached through raw sockets.
class FakeKlapPlug implements LoginPlug {
  FakeKlapPlug({Uint8List? authHash})
    : _authHash = authHash ?? TestFixtures.testAuthHash;

  final Uint8List _authHash;
  final _remoteSeed = Uint8List.fromList(List.filled(16, 1));
  Uint8List _localSeed = Uint8List(16);
  final _sockets = <_FakeSocket>[];

  /// The plug keeps a single session: each login replaces the previous one.
  int _logins = 0;
  String get _sessionCookie => 'TP_SESSIONID=session$_logins';

  @override
  void logInFromAnotherApp() => _logins++;

  /// Whether every socket the app opened has been closed or destroyed.
  bool get allSocketsReleased => _sockets.every((socket) => socket.released);

  PortState port = PortState.open;

  /// Replaces the valid handshake1 answer when set.
  PlugReply? handshake1;

  @override
  PlugReply Function(Map<String, dynamic> request) onRequest = (_) =>
      const JsonReply({'error_code': 0, 'result': <String, dynamic>{}});

  _FakeSocket _openSocket() {
    final socket = _FakeSocket(this);
    _sockets.add(socket);
    return socket;
  }

  Future<Socket> connect(Duration? timeout) => switch (port) {
    PortState.open => Future.value(_openSocket()),
    PortState.refused => Future.error(
      const SocketException('Connection refused'),
    ),
    PortState.dropped when timeout == null => Completer<Socket>().future,
    PortState.dropped => Future.delayed(
      timeout!,
      () => throw const SocketException('Connection timed out'),
    ),
  };

  Stream<Uint8List> _answer(String head, List<int> body) {
    final path = head.split(' ')[1];
    if (path == '/app/handshake1') {
      _logins++;
      _localSeed = Uint8List.fromList(body);
      return _frame(
        handshake1 ??
            RawReply([
              ..._remoteSeed,
              ...sha256HashBytes([..._localSeed, ..._remoteSeed, ..._authHash]),
            ]),
      );
    }
    if (path == '/app/handshake2') return _frame(const RawReply([]));
    if (!head.contains('Cookie: $_sessionCookie\r\n')) {
      return _frame(const StatusReply(HttpStatus.forbidden));
    }

    final iv = _ivFor(int.parse(Uri.parse(path).queryParameters['seq']!));
    final request = aesDecrypt(
      Uint8List.sublistView(Uint8List.fromList(body), 32),
      _derive('lsk', 16),
      iv,
    );
    final reply = onRequest(
      jsonDecode(utf8.decode(request)) as Map<String, dynamic>,
    );
    if (reply is! JsonReply) return _frame(reply);
    final encrypted = aesEncrypt(
      Uint8List.fromList(utf8.encode(jsonEncode(reply.payload))),
      _derive('lsk', 16),
      iv,
    );
    return _frame(RawReply([...Uint8List(32), ...encrypted]));
  }

  Uint8List _derive(String label, int length) => Uint8List.sublistView(
    sha256HashBytes([
      ...utf8.encode(label),
      ..._localSeed,
      ..._remoteSeed,
      ..._authHash,
    ]),
    0,
    length,
  );

  Uint8List _ivFor(int seq) => Uint8List(16)
    ..setAll(0, _derive('iv', 12))
    ..buffer.asByteData().setInt32(12, seq);

  Stream<Uint8List> _frame(PlugReply reply) {
    // The default cancel future belongs to the root zone: breaking out of an
    // `await for` would then resume outside fake time.
    final controller = StreamController<Uint8List>(
      onCancel: Future<void>.value,
    );
    switch (reply) {
      case SilentReply():
        break;
      case HangUpReply():
        unawaited(controller.close());
      case ResetReply():
        controller.addError(const SocketException('Connection reset by peer'));
        unawaited(controller.close());
      case StatusReply(:final statusCode):
        controller.add(
          utf8.encode(
            'HTTP/1.1 $statusCode Error\r\nContent-Length: 0\r\n\r\n',
          ),
        );
        unawaited(controller.close());
      case RawReply(:final bytes):
        controller.add(
          Uint8List.fromList([
            ...utf8.encode(
              'HTTP/1.1 200 OK\r\n'
              'Content-Length: ${bytes.length}\r\n'
              'Set-Cookie: $_sessionCookie\r\n\r\n',
            ),
            ...bytes,
          ]),
        );
        unawaited(controller.close());
      case JsonReply():
        throw UnsupportedError('Encrypt JSON before framing it');
      case DelayedReply():
        throw UnsupportedError('Only TPAP plugs delay replies');
    }
    return controller.stream;
  }
}

class _FakeSocket extends Fake implements Socket {
  _FakeSocket(this._plug);

  final FakeKlapPlug _plug;
  final _sent = <List<int>>[];
  final _done = Completer<void>();
  StreamSubscription<Uint8List>? _subscription;
  bool released = false;

  @override
  void add(List<int> data) => _sent.add(data);

  /// Fails like a real socket's when the connection breaks.
  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    released = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  void destroy() {
    released = true;
    if (!_done.isCompleted) _done.complete();
    unawaited(_subscription?.cancel());
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _subscription = _plug
      ._answer(utf8.decode(_sent.first), [..._sent.skip(1).expand((b) => b)])
      .transform(
        StreamTransformer<Uint8List, Uint8List>.fromHandlers(
          handleError: (error, stackTrace, sink) {
            if (!_done.isCompleted) _done.completeError(error, stackTrace);
            sink.addError(error, stackTrace);
          },
        ),
      )
      .listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}

/// A plug speaking TPAP, reached through [HttpClient].
class FakeTpapPlug {
  /// Answers a POST; connections are refused while null.
  PlugReply Function(Uri url, String body)? onPost;

  /// Every URL a POST was attempted on, refused ones included.
  final requests = <Uri>[];

  final _clients = <_FakeHttpClient>[];
  final _openRequests = <_FakeHttpRequest>{};

  /// Whether every HttpClient the app created has been closed.
  bool get allClientsClosed => _clients.every((client) => client.closed);

  /// Whether every request the app sent was answered or aborted.
  bool get allRequestsFinished => _openRequests.isEmpty;

  HttpClient createClient(SecurityContext? context) {
    final client = _FakeHttpClient(this);
    _clients.add(client);
    return client;
  }

  bool get _acceptsConnections => onPost != null;

  PlugReply _answer(Uri url, List<int> body, String? cookie) =>
      onPost!(url, utf8.decode(body));
}

/// A TPAP plug holding the test account: it logs the app in with SPAKE2+,
/// then answers each decrypted `/app/request` through [onRequest].
class FakeTpapPlugWithLogin extends FakeTpapPlug implements LoginPlug {
  FakeTpapPlugWithLogin({
    this._email = TestFixtures.testEmail,
    this._password = TestFixtures.testPassword,
  });

  final String _email;
  final String _password;
  final List<int> _salt = List.filled(16, 7);
  static const _iterations = 1000;

  @override
  PlugReply Function(Map<String, dynamic> request) onRequest = (_) =>
      const JsonReply({'error_code': 0, 'result': <String, dynamic>{}});

  /// The plug keeps a single session: each login replaces the previous one.
  int _logins = 0;
  String get _sessionId => 'session$_logins';
  _SpakeExchange? _pending;
  _SpakeExchange? _session;

  /// How many times the app completed a login.
  int get appLogins => _appLogins;
  int _appLogins = 0;

  @override
  void logInFromAnotherApp() => _logins++;

  @override
  bool get _acceptsConnections => true;

  @override
  PlugReply _answer(Uri url, List<int> body, String? cookie) {
    switch (url.path) {
      case '/app':
        return JsonReply({
          'result': {
            'salt': base64Encode(_salt),
            'iterations': _iterations,
            'transaction_id': 'tx',
          },
        });
      case '/app/handshake2':
        final params = _params(body);
        final exchange = _pending = _SpakeExchange(
          email: _email,
          password: _password,
          salt: _salt,
          iterations: _iterations,
          clientShare: base64Decode(params['client_share'] as String),
        );
        return JsonReply({
          'result': {
            'server_share': base64Encode(exchange.serverShare),
            'transaction_id': 'tx',
          },
        });
      case '/app/handshake3':
        final exchange = _pending;
        final confirm = base64Decode(_params(body)['client_confirm'] as String);
        if (exchange == null || !exchange.confirmsClient(confirm)) {
          return const StatusReply(HttpStatus.forbidden);
        }
        _logins++;
        _appLogins++;
        _session = exchange;
        return JsonReply({
          'result': {
            'server_confirm': base64Encode(exchange.serverConfirm),
            'session_id': _sessionId,
            'start_seq': 1,
            'cipher_suite': 1,
          },
        });
      case '/app/request':
        final session = _session;
        if (session == null || cookie != 'TP_SESSIONID=$_sessionId') {
          return const StatusReply(HttpStatus.forbidden);
        }
        final seq = int.parse(url.queryParameters['seq']!);
        final request = session
            .cipher(seq)
            .decryptWithSeq(Uint8List.fromList(body), seq);
        return _seal(
          onRequest(jsonDecode(utf8.decode(request)) as Map<String, dynamic>),
          session,
          seq,
        );
    }
    return const StatusReply(HttpStatus.notFound);
  }

  /// Encrypts JSON replies with the nonce the app reads them with: the one
  /// following the request's.
  PlugReply _seal(PlugReply reply, _SpakeExchange session, int seq) =>
      switch (reply) {
        JsonReply(:final payload) => RawReply(
          session
              .cipher(seq)
              .encrypt(Uint8List.fromList(utf8.encode(jsonEncode(payload)))),
        ),
        DelayedReply(:final delay, :final reply) => DelayedReply(
          delay,
          _seal(reply, session, seq),
        ),
        _ => reply,
      };

  static Map<String, dynamic> _params(List<int> body) =>
      (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['params']
          as Map<String, dynamic>;
}

/// The plug's side of a SPAKE2+ exchange (RFC 9383, P-256), as the app's
/// Spake2Plus expects it.
class _SpakeExchange {
  _SpakeExchange({
    required String email,
    required String password,
    required List<int> salt,
    required int iterations,
    required Uint8List clientShare,
  }) {
    final derived =
        (PBKDF2KeyDerivator(
              HMac(SHA256Digest(), 64),
            )..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, 80)))
            .process(Uint8List.fromList(utf8.encode(password)));
    final w0 = _toBigInt(derived.sublist(0, 40)) % _curve.n;
    final w1 = _toBigInt(derived.sublist(40, 80)) % _curve.n;

    // Fixed: a test plug needs no secret.
    final y = BigInt.from(424242);
    final x = _curve.curve.decodePoint(clientShare)!;
    final yPoint = ((_curve.G * y)! + (_n * w0))!;
    final z = ((x + (-(_m * w0)!))! * y)!;
    final v = ((_curve.G * w1)! * y)!;
    serverShare = yPoint.getEncoded();

    final transcript = BytesBuilder();
    for (final field in [
      utf8.encode('PAKE V1'),
      utf8.encode(email),
      <int>[],
      _m.getEncoded(false),
      _n.getEncoded(false),
      x.getEncoded(false),
      yPoint.getEncoded(false),
      z.getEncoded(false),
      v.getEncoded(false),
      _toBytes(w0, 32),
    ]) {
      transcript
        ..add(
          (ByteData(
            8,
          )..setUint64(0, field.length, Endian.little)).buffer.asUint8List(),
        )
        ..add(field);
    }
    final kMain = Uint8List.fromList(
      sha256.convert(transcript.toBytes()).bytes,
    );
    final confirmKeys = TpapHkdf.expand(
      kMain,
      Uint8List.fromList(utf8.encode('ConfirmationKeys')),
      64,
    );
    _clientConfirm = Hmac(
      sha256,
      confirmKeys.sublist(0, 32),
    ).convert(serverShare).bytes;
    serverConfirm = Uint8List.fromList(
      Hmac(sha256, confirmKeys.sublist(32)).convert(clientShare).bytes,
    );

    final sharedKey = TpapHkdf.expand(
      kMain,
      Uint8List.fromList(utf8.encode('SharedKey')),
      32,
    );
    _key = TpapHkdf.expand(
      sharedKey,
      Uint8List.fromList(utf8.encode('SessionKey')),
      32,
    );
    _baseNonce = TpapHkdf.expand(
      sharedKey,
      Uint8List.fromList(utf8.encode('SessionNonce')),
      12,
    );
  }

  static final _curve = ECCurve_secp256r1();
  static final ECPoint _m = _curve.curve.decodePoint(
    _hex('02886e2f97ace46e55ba9dd7242579f2993b64e16ef3dcab95afd497333d8fa12f'),
  )!;
  static final ECPoint _n = _curve.curve.decodePoint(
    _hex('03d8bbd6c639c62937b04d997f38c3770719c629d7014d49a24b4f98baa1292b49'),
  )!;

  late final Uint8List serverShare;
  late final Uint8List serverConfirm;
  late final List<int> _clientConfirm;
  late final Uint8List _key;
  late final Uint8List _baseNonce;

  bool confirmsClient(List<int> confirm) => bytesEqual(
    Uint8List.fromList(confirm),
    Uint8List.fromList(_clientConfirm),
  );

  /// A cipher whose next nonce follows [seq].
  TpapSessionCipher cipher(int seq) => TpapSessionCipher(
    key: _key,
    baseNonce: _baseNonce,
    cipherSuite: 1,
    startSeq: seq,
  );

  static BigInt _toBigInt(List<int> bytes) => bytes.fold(
    BigInt.zero,
    (value, byte) => (value << 8) | BigInt.from(byte),
  );

  static Uint8List _toBytes(BigInt value, int length) => Uint8List.fromList([
    for (var i = length - 1; i >= 0; i--)
      ((value >> (8 * i)) & BigInt.from(0xff)).toInt(),
  ]);

  static Uint8List _hex(String hex) => Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

class _FakeHttpClient extends Fake implements HttpClient {
  _FakeHttpClient(this._plug);

  final FakeTpapPlug _plug;
  final _requests = <_FakeHttpRequest>{};
  bool closed = false;

  @override
  Duration? connectionTimeout;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? callback,
  ) {}

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    if (closed) throw StateError('Client is closed');
    _plug.requests.add(url);
    if (!_plug._acceptsConnections) {
      throw const SocketException('Connection refused');
    }
    return _FakeHttpRequest(this, url);
  }

  /// Unless [force], requests in flight still get their answer.
  @override
  void close({bool force = false}) {
    closed = true;
    if (!force) return;
    for (final request in [..._requests]) {
      request._fail(const HttpException('Client closed'));
    }
  }
}

class _FakeHttpRequest extends Fake implements HttpClientRequest {
  _FakeHttpRequest(this._client, this._url);

  final _FakeHttpClient _client;
  final Uri _url;
  final _body = <int>[];
  final _response = Completer<HttpClientResponse>();

  @override
  final _FakeHttpHeaders headers = _FakeHttpHeaders();

  @override
  void add(List<int> data) => _body.addAll(data);

  @override
  Future<HttpClientResponse> close() {
    _client._requests.add(this);
    _client._plug._openRequests.add(this);
    unawaited(
      _respond(
        _client._plug._answer(_url, _body, headers.value('Cookie')),
      ).then(_finish, onError: _fail),
    );
    return _response.future;
  }

  void _finish(HttpClientResponse response) {
    if (_response.isCompleted) return;
    _forget();
    _response.complete(response);
  }

  void _fail(Object error) {
    if (_response.isCompleted) return;
    _forget();
    _response.completeError(error);
  }

  void _forget() {
    _client._requests.remove(this);
    _client._plug._openRequests.remove(this);
  }

  static Future<HttpClientResponse> _respond(PlugReply reply) =>
      switch (reply) {
        SilentReply() => Completer<HttpClientResponse>().future,
        HangUpReply() => Future.error(
          const HttpException('Connection closed before full header'),
        ),
        ResetReply() => Future.error(
          const SocketException('Connection reset by peer'),
        ),
        StatusReply(:final statusCode) => Future.value(
          _FakeHttpResponse(const [], statusCode: statusCode),
        ),
        RawReply(:final bytes) => Future.value(_FakeHttpResponse(bytes)),
        JsonReply(:final payload) => Future.value(
          _FakeHttpResponse(utf8.encode(jsonEncode(payload))),
        ),
        DelayedReply(:final delay, :final reply) => Future.delayed(
          delay,
          () => _respond(reply),
        ),
      };
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final _values = <String, String>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values[name] = '$value';

  @override
  String? value(String name) => _values[name];
}

class _FakeHttpResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _FakeHttpResponse(List<int> body, {this.statusCode = HttpStatus.ok})
    : super(Stream.value(body));

  @override
  final int statusCode;

  @override
  List<Cookie> get cookies => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
