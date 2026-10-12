import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/core/validators.dart';

void main() {
  group('isValidIpv4', () {
    for (final ip in [
      '192.168.1.100',
      '10.0.0.1',
      '0.0.0.0',
      '255.255.255.255',
    ]) {
      test('accepts $ip', () => expect(isValidIpv4(ip), isTrue));
    }

    for (final ip in [
      '256.1.1.1',
      '1.2.3',
      '1.2.3.4.5',
      'a.b.c.d',
      'plug.local',
      '+1.2.3.4',
      '-0.1.1.1',
      '010.1.1.1',
      '1.2.3. 4',
      '',
    ]) {
      test("rejects '$ip'", () => expect(isValidIpv4(ip), isFalse));
    }
  });
}
