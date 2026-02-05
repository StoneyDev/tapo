import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tapo/core/http_utils.dart';
import 'package:tapo/core/klap_crypto.dart';
import 'package:tapo/core/klap_session.dart';

/// Client for Tapo devices via KLAP protocol
/// Matches python-kasa encrypt/decrypt implementation
class TapoClient {
  TapoClient({required this.session});

  final KlapSession session;

  Future<Map<String, dynamic>?> getDeviceInfo() async {
    final response = await _request({'method': 'get_device_info'});
    if (response == null) return null;
    return response['result'] as Map<String, dynamic>?;
  }

  Future<bool> setDeviceOn({required bool on}) async {
    final response = await _request({
      'method': 'set_device_info',
      'params': {'device_on': on},
    });
    return response != null;
  }

  Future<Map<String, dynamic>?> _request(Map<String, dynamic> payload) async {
    if (!session.isEstablished) return null;

    try {
      // Encrypt (matches python-kasa encrypt method)
      session.seq++;
      final seqNum = session.seq;

      // Generate IV for this seq
      final iv = session.generateIv();

      // Encrypt payload with PKCS7 padding
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final encrypted = aesEncrypt(
        Uint8List.fromList(payloadBytes),
        session.key!,
        iv,
      );

      // Signature: SHA256(sig + seq_bytes + ciphertext)
      final seqBytes = ByteData(4)..setInt32(0, seqNum);
      final signature = sha256HashBytes([
        ...session.sig!,
        ...seqBytes.buffer.asUint8List(),
        ...encrypted,
      ]);

      // Request body: signature (32) + ciphertext
      final body = Uint8List.fromList([...signature, ...encrypted]);

      // Send via raw socket
      final socket = await Socket.connect(session.deviceIp, 80);
      final request =
          'POST /app/request?seq=$seqNum HTTP/1.1\r\n'
          'Host: ${session.deviceIp}\r\n'
          'Content-Type: application/octet-stream\r\n'
          'Content-Length: ${body.length}\r\n'
          'Cookie: ${session.sessionCookie}\r\n'
          'Accept: */*\r\n'
          '\r\n';

      socket
        ..add(utf8.encode(request))
        ..add(body);

      final response = await readHttpResponse(socket);
      await socket.close();

      if (response.statusCode != 200 || response.body.length < 32) return null;

      // Decrypt: skip signature (32 bytes), decrypt the rest
      final ciphertext = Uint8List.sublistView(response.body, 32);
      final decrypted = aesDecrypt(ciphertext, session.key!, iv);
      final result = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;

      return result['error_code'] == 0 ? result : null;
    } on Exception {
      return null;
    }
  }
}
