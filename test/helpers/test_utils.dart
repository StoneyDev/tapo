import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mockito/annotations.dart';
import 'package:tapo/core/klap_crypto.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';

@GenerateMocks([SecureStorageService, TapoService, FlutterSecureStorage, WidgetDataService])
void main() {}

class TestFixtures {
  static const testDeviceIp = '192.168.1.100';
  static const testDeviceIp2 = '192.168.1.101';
  static const testEmail = 'test@example.com';
  static const testPassword = 'testpassword123';

  static Uint8List get testAuthHash =>
      generateAuthHash(testEmail, testPassword);

  static TapoDevice onlineDevice({
    String ip = testDeviceIp,
    String nickname = 'Test Plug',
    String model = 'P110',
    bool deviceOn = true,
  }) =>
      TapoDevice(
        ip: ip,
        nickname: nickname,
        model: model,
        deviceOn: deviceOn,
        isOnline: true,
      );

  static TapoDevice offlineDevice({
    String ip = testDeviceIp,
  }) =>
      TapoDevice(
        ip: ip,
        nickname: 'Unknown',
        model: 'Unknown',
        deviceOn: false,
        isOnline: false,
      );

  static Map<String, dynamic> deviceInfoResponse({
    String nickname = 'Test Plug',
    String model = 'P110',
    bool deviceOn = true,
  }) =>
      {
        'nickname': nickname,
        'model': model,
        'device_on': deviceOn,
      };
}
