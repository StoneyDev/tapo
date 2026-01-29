import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/http_utils.dart';

void main() {
  group('HttpResponse', () {
    test('stores statusCode, body, and cookie', () {
      final body = Uint8List.fromList([1, 2, 3]);
      final response = HttpResponse(
        statusCode: 200,
        body: body,
        cookie: 'session=abc123',
      );

      expect(response.statusCode, 200);
      expect(response.body, body);
      expect(response.cookie, 'session=abc123');
    });

    test('cookie can be null', () {
      final response = HttpResponse(
        statusCode: 404,
        body: Uint8List(0),
      );

      expect(response.statusCode, 404);
      expect(response.cookie, isNull);
    });

    test('body can be empty', () {
      final response = HttpResponse(
        statusCode: 204,
        body: Uint8List(0),
      );

      expect(response.body.length, 0);
    });
  });

  // Note: readHttpResponse requires real sockets which are difficult to mock.
  // Integration tests would be more appropriate for testing that function.
  // The HttpResponse class is the primary testable unit here.
}
