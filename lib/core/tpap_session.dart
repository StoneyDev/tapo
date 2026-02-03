import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tapo/core/spake2plus.dart';
import 'package:tapo/core/tpap_crypto.dart';

/// TPAP session for Tapo devices with firmware 1.4+
/// Uses TLS on port 4433 with SPAKE2+ authentication
class TpapSession {
  TpapSession({required this.deviceIp, required this.credentials});

  final String deviceIp;
  final TpapCredentials credentials;

  HttpClient? _httpClient;
  String? _sessionId;
  TpapSessionCipher? _cipher;
  int _seq = 0;

  bool get isEstablished => _cipher != null && _sessionId != null;

  /// Probe device to understand what protocol it supports
  Future<void> probeDevice() async {
    _httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);

    final endpoints = ['/app', '/app/handshake', '/app/login', '/'];
    final methods = [
      {'method': 'get_device_info'},
      {'method': 'handshake'},
      {'method': 'login'},
      {'method': 'securePassthrough', 'params': <String, dynamic>{}},
    ];

    for (final endpoint in endpoints) {
      for (final method in methods) {
        try {
          final uri = Uri.parse('http://$deviceIp$endpoint');
          final request = await _httpClient!.postUrl(uri)
            ..headers.set('Content-Type', 'application/json')
            ..add(utf8.encode(jsonEncode(method)));
          final response = await request.close();
          await response.drain<void>();
        } on Exception {
          // Ignore probe errors
        }
        _httpClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 5);
      }
    }
  }

  /// Test TLS connection to device on port 4433 (for robot vacuums)
  Future<bool> testTlsConnection() async {
    try {
      _httpClient = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;

      final uri = Uri.parse('https://$deviceIp:4433/app');
      final request = await _httpClient!.getUrl(uri);
      final response = await request.close();
      await response.drain<void>();

      return true;
    } on Exception {
      return false;
    }
  }

  /// Perform full TPAP handshake (SPAKE2+)
  Future<bool> handshake() async {
    try {
      _httpClient = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;

      // Step 1: Initial handshake to get parameters
      final initResult = await _initHandshake();
      if (initResult == null) return false;

      // Step 2: SPAKE2+ key exchange
      final spake = Spake2Plus(
        identity: credentials.email,
        password: credentials.password,
        iterations: initResult.iterations,
      );

      // Generate our public share
      final clientShare = spake.generatePublicShare(
        initResult.salt,
        initResult.iterations,
      );

      // Send client share, receive server share
      final serverShare = await _sendClientShare(
        clientShare, initResult.transactionId,
      );
      if (serverShare == null) return false;

      // Process server share and get confirmation
      final clientConfirm = spake.processServerShare(serverShare.share);
      if (clientConfirm == null) return false;

      // Send confirmation, receive server confirmation
      final serverConfirm = await _sendConfirmation(
        clientConfirm,
        serverShare.transactionId,
      );
      if (serverConfirm == null) return false;

      // Verify server confirmation
      if (!spake.verifyServerConfirmation(serverConfirm.confirmation)) {
        return false;
      }

      // Setup session cipher
      _sessionId = serverConfirm.sessionId;
      _seq = serverConfirm.startSeq;

      final sharedKey = spake.sharedKey;
      if (sharedKey == null) return false;

      // Derive cipher key and nonce from shared key
      final cipherKey = TpapHkdf.expand(
        sharedKey,
        Uint8List.fromList(utf8.encode('SessionKey')),
        32,
      );
      final baseNonce = TpapHkdf.expand(
        sharedKey,
        Uint8List.fromList(utf8.encode('SessionNonce')),
        12,
      );

      _cipher = TpapSessionCipher(
        key: cipherKey,
        baseNonce: baseNonce,
        cipherSuite: serverConfirm.cipherSuite,
        startSeq: _seq,
      );

      return true;
    } on Exception {
      await close();
      return false;
    }
  }

  /// Send encrypted request and get response
  Future<Map<String, dynamic>?> request(Map<String, dynamic> payload) async {
    if (!isEstablished) return null;

    try {
      final payloadJson = jsonEncode(payload);
      final payloadBytes = utf8.encode(payloadJson);

      // Encrypt
      final encrypted = _cipher!.encrypt(Uint8List.fromList(payloadBytes));
      final seq = _cipher!.seq;

      // Send request
      final uri = Uri.parse(
        'https://$deviceIp:4433/app/request?seq=$seq',
      );
      final request = await _httpClient!.postUrl(uri)
        ..headers.set('Content-Type', 'application/octet-stream')
        ..headers.set('Cookie', 'TP_SESSIONID=$_sessionId')
        ..add(encrypted);

      final response = await request.close();
      if (response.statusCode != 200) return null;

      // Read and decrypt response
      final responseBytes = await response.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );

      final decrypted = _cipher!.decrypt(Uint8List.fromList(responseBytes));
      final result =
          jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;

      return result['error_code'] == 0 ? result : null;
    } on Exception {
      return null;
    }
  }

  Future<_InitResult?> _initHandshake() async {
    // P110 with TPAP uses HTTP port 80, not HTTPS 4433
    try {
      // First try port 80 (P110 TPAP)
      final uri80 = Uri.parse('http://$deviceIp/app');
      final request80 = await _httpClient!.postUrl(uri80)
        ..headers.set('Content-Type', 'application/json');

      // Try a simple handshake request
      final initPayload = jsonEncode({
        'method': 'handshake',
        'params': {
          'username': credentials.email,
        },
      });
      request80.add(utf8.encode(initPayload));

      final response80 = await request80.close();
      final body80 = await response80.transform(utf8.decoder).join();

      if (response80.statusCode == 200) {
        final result = jsonDecode(body80) as Map<String, dynamic>;
        final params = result['result'] as Map<String, dynamic>?;
        if (params != null) {
          return _InitResult(
            salt: base64Decode(params['salt'] as String? ?? ''),
            iterations: params['iterations'] as int? ?? 1000,
            transactionId: params['transaction_id'] as String? ?? '',
          );
        }
      }

      // If port 80 fails, try port 4433 (robot vacuums)
      _httpClient!.badCertificateCallback = (_, __, ___) => true;

      final uri4433 = Uri.parse('https://$deviceIp:4433/app/handshake1');
      final request4433 = await _httpClient!.postUrl(uri4433)
        ..headers.set('Content-Type', 'application/json');

      final loginPayload = jsonEncode({
        'method': 'login',
        'params': {'username': credentials.email},
      });
      request4433.add(utf8.encode(loginPayload));

      final response4433 = await request4433.close();
      if (response4433.statusCode != 200) return null;

      final body4433 = await response4433.transform(utf8.decoder).join();
      final result = jsonDecode(body4433) as Map<String, dynamic>;
      final params = result['result'] as Map<String, dynamic>?;
      if (params == null) return null;

      return _InitResult(
        salt: base64Decode(params['salt'] as String? ?? ''),
        iterations: params['iterations'] as int? ?? 1000,
        transactionId: params['transaction_id'] as String? ?? '',
      );
    } on Exception {
      return null;
    }
  }

  Future<_ShareResult?> _sendClientShare(
    Uint8List clientShare,
    String transactionId,
  ) async {
    try {
      final uri = Uri.parse('https://$deviceIp:4433/app/handshake2');
      final request = await _httpClient!.postUrl(uri)
        ..headers.set('Content-Type', 'application/json');

      final payload = jsonEncode({
        'method': 'login',
        'params': {
          'client_share': base64Encode(clientShare),
          'transaction_id': transactionId,
        },
      });
      request.add(utf8.encode(payload));

      final response = await request.close();
      if (response.statusCode != 200) return null;

      final responseBody = await response.transform(utf8.decoder).join();
      final result = jsonDecode(responseBody) as Map<String, dynamic>;
      final params = result['result'] as Map<String, dynamic>?;
      if (params == null) return null;

      return _ShareResult(
        share: base64Decode(params['server_share'] as String? ?? ''),
        transactionId: params['transaction_id'] as String? ?? transactionId,
      );
    } on Exception {
      return null;
    }
  }

  Future<_ConfirmResult?> _sendConfirmation(
    Uint8List clientConfirm,
    String transactionId,
  ) async {
    try {
      final uri = Uri.parse('https://$deviceIp:4433/app/handshake3');
      final request = await _httpClient!.postUrl(uri)
        ..headers.set('Content-Type', 'application/json');

      final payload = jsonEncode({
        'method': 'login',
        'params': {
          'client_confirm': base64Encode(clientConfirm),
          'transaction_id': transactionId,
        },
      });
      request.add(utf8.encode(payload));

      final response = await request.close();
      if (response.statusCode != 200) return null;

      // Extract session cookie
      final cookies = response.cookies;
      String? sessionId;
      for (final cookie in cookies) {
        if (cookie.name == 'TP_SESSIONID') {
          sessionId = cookie.value;
          break;
        }
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final result = jsonDecode(responseBody) as Map<String, dynamic>;
      final params = result['result'] as Map<String, dynamic>?;
      if (params == null) return null;

      return _ConfirmResult(
        confirmation: base64Decode(params['server_confirm'] as String? ?? ''),
        sessionId: sessionId ?? params['session_id'] as String? ?? '',
        startSeq: params['start_seq'] as int? ?? 0,
        cipherSuite: params['cipher_suite'] as int? ?? 1,
      );
    } on Exception {
      return null;
    }
  }

  Future<void> close() async {
    _httpClient?.close();
    _httpClient = null;
    _sessionId = null;
    _cipher = null;
  }
}

/// Credentials for TPAP authentication
class TpapCredentials {
  TpapCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class _InitResult {
  _InitResult({
    required this.salt,
    required this.iterations,
    required this.transactionId,
  });

  final Uint8List salt;
  final int iterations;
  final String transactionId;
}

class _ShareResult {
  _ShareResult({required this.share, required this.transactionId});

  final Uint8List share;
  final String transactionId;
}

class _ConfirmResult {
  _ConfirmResult({
    required this.confirmation,
    required this.sessionId,
    required this.startSeq,
    required this.cipherSuite,
  });

  final Uint8List confirmation;
  final String sessionId;
  final int startSeq;
  final int cipherSuite;
}
