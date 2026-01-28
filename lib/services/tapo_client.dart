import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  Future<Map<String, dynamic>?> _request(
    Map<String, dynamic> payload,
  ) async {
    if (!session.isEstablished) {
      return null;
    }

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
      final request = 'POST /app/request?seq=$seqNum HTTP/1.1\r\n'
          'Host: ${session.deviceIp}\r\n'
          'Content-Type: application/octet-stream\r\n'
          'Content-Length: ${body.length}\r\n'
          'Cookie: ${session.sessionCookie}\r\n'
          'Accept: */*\r\n'
          '\r\n';

      socket
        ..add(utf8.encode(request))
        ..add(body);

      // Read response
      final responseData = <int>[];
      await for (final chunk in socket) {
        responseData.addAll(chunk);
        final str = utf8.decode(responseData, allowMalformed: true);
        if (str.contains('\r\n\r\n')) {
          final headerEnd = str.indexOf('\r\n\r\n');
          final headers = str.substring(0, headerEnd);
          final clMatch =
              RegExp(r'Content-Length: (\d+)').firstMatch(headers);
          if (clMatch != null) {
            final cl = int.parse(clMatch.group(1)!);
            if (responseData.length >= headerEnd + 4 + cl) break;
          } else {
            break;
          }
        }
      }
      await socket.close();

      final responseStr = utf8.decode(responseData, allowMalformed: true);
      final statusCode = int.parse(responseStr.split(' ')[1]);

      if (statusCode != 200) {
        return null;
      }

      // Find body
      var bodyStart = 0;
      for (var i = 0; i < responseData.length - 3; i++) {
        if (responseData[i] == 13 &&
            responseData[i + 1] == 10 &&
            responseData[i + 2] == 13 &&
            responseData[i + 3] == 10) {
          bodyStart = i + 4;
          break;
        }
      }
      final responseBody = Uint8List.fromList(
        responseData.sublist(bodyStart),
      );

      if (responseBody.length < 32) {
        return null;
      }

      // Decrypt (matches python-kasa decrypt method)
      // Skip signature (32 bytes), decrypt the rest
      final responseCiphertext = Uint8List.sublistView(responseBody, 32);
      final decrypted = aesDecrypt(responseCiphertext, session.key!, iv);
      final jsonStr = utf8.decode(decrypted);

      final result = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (result['error_code'] != 0) {
        return null;
      }

      return result;
    } on Exception {
      return null;
    }
  }
}
