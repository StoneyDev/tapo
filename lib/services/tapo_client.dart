import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/klap_session.dart';
import '../core/klap_crypto.dart';

/// Client for communicating with Tapo devices via KLAP protocol
class TapoClient {
  final KlapSession session;

  TapoClient({required this.session});

  String get _baseUrl => 'http://${session.deviceIp}/app';

  /// Get device info (nickname, model, device_on state)
  /// Returns null if request fails
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    final response = await _request({'method': 'get_device_info'});
    if (response == null) return null;

    final result = response['result'] as Map<String, dynamic>?;
    return result;
  }

  /// Set device on/off state
  /// Returns true on success, false on failure
  Future<bool> setDeviceOn(bool on) async {
    final response = await _request({
      'method': 'set_device_info',
      'params': {'device_on': on},
    });
    return response != null;
  }

  /// Send encrypted request to device
  /// Returns decoded JSON response or null on failure
  Future<Map<String, dynamic>?> _request(Map<String, dynamic> payload) async {
    if (!session.isEstablished) return null;

    try {
      // Increment seq for this request
      session.seq++;
      final seqNum = session.seq;

      // Encode payload to JSON bytes
      final payloadJson = utf8.encode(jsonEncode(payload));

      // Get IV for this seq
      final iv = session.getIvForSeq(seqNum);

      // Encrypt payload
      final encrypted = aesEncrypt(
        Uint8List.fromList(payloadJson),
        session.key!,
        iv,
      );

      // Create signature: SHA256(sig_prefix + seq_bytes + encrypted)
      final seqBytes = ByteData(4)..setInt32(0, seqNum, Endian.big);
      final sigInput = [
        ...sha256HashBytes([
          ...utf8.encode('lsk'),
          ...session.key!,
        ]),
        ...seqBytes.buffer.asUint8List(),
        ...encrypted,
      ];
      final signature = sha256HashBytes(sigInput);

      // Build request body: signature (32) + encrypted
      final body = Uint8List.fromList([...signature, ...encrypted]);

      // Send request
      final response = await http.post(
        Uri.parse('$_baseUrl/request?seq=$seqNum'),
        headers: {
          'Cookie': session.sessionCookie!,
          'Content-Type': 'application/octet-stream',
        },
        body: body,
      );

      if (response.statusCode != 200) return null;

      // Response format: signature (32) + encrypted data
      final responseBody = response.bodyBytes;
      if (responseBody.length < 32) return null;

      final responseEncrypted = Uint8List.sublistView(responseBody, 32);

      // Decrypt response
      final decrypted = aesDecrypt(responseEncrypted, session.key!, iv);

      // Parse JSON
      final jsonStr = utf8.decode(decrypted);
      final result = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Check error_code
      if (result['error_code'] != 0) return null;

      return result;
    } catch (e) {
      return null;
    }
  }
}
