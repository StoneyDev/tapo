import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/klap_crypto.dart';

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

/// Answers 403 with no body, as a plug does for a session it no longer has.
class ForbiddenReply extends PlugReply {
  const ForbiddenReply();
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

/// A plug speaking KLAP on port 80, reached through raw sockets.
class FakeKlapPlug {
  FakeKlapPlug({Uint8List? authHash})
    : _authHash = authHash ?? TestFixtures.testAuthHash;

  final Uint8List _authHash;
  final _remoteSeed = Uint8List.fromList(List.filled(16, 1));
  Uint8List _localSeed = Uint8List(16);
  final _sockets = <_FakeSocket>[];

  /// The plug keeps a single session: each login replaces the previous one.
  int _logins = 0;
  String get _sessionCookie => 'TP_SESSIONID=session$_logins';

  /// Another app logs in to the plug, which drops the app's session.
  void logInFromAnotherApp() => _logins++;

  /// Whether every socket the app opened has been closed or destroyed.
  bool get allSocketsReleased => _sockets.every((socket) => socket.released);

  PortState port = PortState.open;

  /// Replaces the valid handshake1 answer when set.
  PlugReply? handshake1;

  /// Answers a decrypted `/app/request`.
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
      return _frame(const ForbiddenReply());
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
      case ForbiddenReply():
        controller.add(
          utf8.encode('HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n'),
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
  StreamSubscription<Uint8List>? _subscription;
  bool released = false;

  @override
  void add(List<int> data) => _sent.add(data);

  @override
  Future<void> close() async => released = true;

  @override
  void destroy() {
    released = true;
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

  /// Whether every HttpClient the app created has been closed.
  bool get allClientsClosed => _clients.every((client) => client.closed);

  HttpClient createClient(SecurityContext? context) {
    final client = _FakeHttpClient(this);
    _clients.add(client);
    return client;
  }
}

class _FakeHttpClient extends Fake implements HttpClient {
  _FakeHttpClient(this._plug);

  final FakeTpapPlug _plug;
  bool closed = false;

  @override
  Duration? connectionTimeout;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? callback,
  ) {}

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    _plug.requests.add(url);
    final onPost = _plug.onPost;
    if (onPost == null) throw const SocketException('Connection refused');
    return _FakeHttpRequest(url, onPost);
  }

  @override
  void close({bool force = false}) => closed = true;
}

class _FakeHttpRequest extends Fake implements HttpClientRequest {
  _FakeHttpRequest(this._url, this._onPost);

  final Uri _url;
  final PlugReply Function(Uri url, String body) _onPost;
  final _body = <int>[];

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  void add(List<int> data) => _body.addAll(data);

  @override
  Future<HttpClientResponse> close() =>
      _respond(_onPost(_url, utf8.decode(_body)));

  static Future<HttpClientResponse> _respond(PlugReply reply) =>
      switch (reply) {
        SilentReply() => Completer<HttpClientResponse>().future,
        HangUpReply() => Future.error(
          const HttpException('Connection closed before full header'),
        ),
        ForbiddenReply() => Future.value(
          _FakeHttpResponse(const [], statusCode: HttpStatus.forbidden),
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
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
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
