import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Simple HTTP response container
class HttpResponse {
  const HttpResponse({
    required this.statusCode,
    required this.body,
    this.cookie,
  });

  final int statusCode;
  final Uint8List body;
  final String? cookie;
}

/// Read raw HTTP response from socket
Future<HttpResponse> readHttpResponse(Socket socket) async {
  final data = <int>[];

  await for (final chunk in socket) {
    data.addAll(chunk);
    final str = utf8.decode(data, allowMalformed: true);
    if (str.contains('\r\n\r\n')) {
      final headerEnd = str.indexOf('\r\n\r\n');
      final headers = str.substring(0, headerEnd);
      final clMatch = RegExp(r'Content-Length: (\d+)').firstMatch(headers);
      if (clMatch != null) {
        final cl = int.parse(clMatch.group(1)!);
        if (data.length >= headerEnd + 4 + cl) break;
      } else {
        break;
      }
    }
  }

  final str = utf8.decode(data, allowMalformed: true);
  final statusCode = int.parse(str.split(' ')[1]);

  String? cookie;
  final cookieMatch = RegExp(r'Set-Cookie: ([^;\r\n]+)').firstMatch(str);
  if (cookieMatch != null) {
    cookie = cookieMatch.group(1);
  }

  final bodyStart = _findBodyStart(data);
  return HttpResponse(
    statusCode: statusCode,
    body: Uint8List.fromList(data.sublist(bodyStart)),
    cookie: cookie,
  );
}

int _findBodyStart(List<int> data) {
  for (var i = 0; i < data.length - 3; i++) {
    if (data[i] == 13 &&
        data[i + 1] == 10 &&
        data[i + 2] == 13 &&
        data[i + 3] == 10) {
      return i + 4;
    }
  }
  return 0;
}
