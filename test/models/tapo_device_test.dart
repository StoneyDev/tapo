import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/models/tapo_device.dart';

void main() {
  group('TapoDevice', () {
    test('creates instance with required fields', () {
      const device = TapoDevice(
        ip: '192.168.1.100',
        nickname: 'Living Room',
        model: 'P110',
        deviceOn: true,
        isOnline: true,
      );

      expect(device.ip, '192.168.1.100');
      expect(device.nickname, 'Living Room');
      expect(device.model, 'P110');
      expect(device.deviceOn, isTrue);
      expect(device.isOnline, isTrue);
    });

    test('copyWith creates new instance with modified fields', () {
      const original = TapoDevice(
        ip: '192.168.1.100',
        nickname: 'Original',
        model: 'P110',
        deviceOn: true,
        isOnline: true,
      );

      final modified = original.copyWith(nickname: 'Modified', deviceOn: false);

      expect(modified.ip, '192.168.1.100'); // unchanged
      expect(modified.nickname, 'Modified'); // changed
      expect(modified.deviceOn, isFalse); // changed
      expect(original.nickname, 'Original'); // original unchanged
    });

    test('equality works correctly', () {
      const device1 = TapoDevice(
        ip: '192.168.1.100',
        nickname: 'Test',
        model: 'P110',
        deviceOn: true,
        isOnline: true,
      );

      const device2 = TapoDevice(
        ip: '192.168.1.100',
        nickname: 'Test',
        model: 'P110',
        deviceOn: true,
        isOnline: true,
      );

      const device3 = TapoDevice(
        ip: '192.168.1.101', // different IP
        nickname: 'Test',
        model: 'P110',
        deviceOn: true,
        isOnline: true,
      );

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
    });

    test('hashCode is consistent with equality', () {
      const device1 = TapoDevice(
        ip: '192.168.1.100',
        nickname: 'Test',
        model: 'P110',
        deviceOn: true,
        isOnline: true,
      );

      const device2 = TapoDevice(
        ip: '192.168.1.100',
        nickname: 'Test',
        model: 'P110',
        deviceOn: true,
        isOnline: true,
      );

      expect(device1.hashCode, device2.hashCode);
    });

    test('toString returns readable representation', () {
      const device = TapoDevice(
        ip: '192.168.1.100',
        nickname: 'Test',
        model: 'P110',
        deviceOn: true,
        isOnline: true,
      );

      final str = device.toString();
      expect(str, contains('TapoDevice'));
      expect(str, contains('192.168.1.100'));
    });
  });
}
