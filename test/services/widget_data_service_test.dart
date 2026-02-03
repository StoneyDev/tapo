import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/services/widget_data_service.dart';

import '../helpers/test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WidgetDataService service;

  /// In-memory store for widget data keyed by id.
  late Map<String, dynamic> widgetStore;

  List<Map<String, dynamic>> readDevices() {
    final json = widgetStore['devices'] as String;
    return (jsonDecode(json) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  setUp(() {
    service = WidgetDataService();
    widgetStore = {};

    // Mock the home_widget MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (
          MethodCall call,
        ) async {
          switch (call.method) {
            case 'saveWidgetData':
              final args = call.arguments as Map;
              final id = args['id'] as String;
              final data = args['data'];
              if (data == null) {
                widgetStore.remove(id);
              } else {
                widgetStore[id] = data;
              }
              return true;
            case 'getWidgetData':
              final args = call.arguments as Map;
              final id = args['id'] as String;
              return widgetStore[id] ?? args['defaultValue'];
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  group('WidgetDataService', () {
    group('saveDeviceState', () {
      test('saves single device to empty store', () async {
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp,
          model: 'P110',
          deviceOn: true,
        );

        final stored = readDevices();
        expect(stored, hasLength(1));
        expect(stored[0]['ip'], TestFixtures.testDeviceIp);
        expect(stored[0]['model'], 'P110');
        expect(stored[0]['deviceOn'], true);
        expect(stored[0]['isOnline'], true);
      });

      test('defaults isOnline to true', () async {
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp,
          model: 'P110',
          deviceOn: false,
        );

        final stored = readDevices();
        expect(stored[0]['isOnline'], true);
      });

      test('saves device with isOnline=false', () async {
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp,
          model: 'P110',
          deviceOn: false,
          isOnline: false,
        );

        final stored = readDevices();
        expect(stored[0]['isOnline'], false);
      });

      test('updates existing device by IP', () async {
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp,
          model: 'P110',
          deviceOn: true,
        );
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp,
          model: 'P110',
          deviceOn: false,
        );

        final stored = readDevices();
        expect(stored, hasLength(1));
        expect(stored[0]['deviceOn'], false);
      });

      test('appends new device with different IP', () async {
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp,
          model: 'P110',
          deviceOn: true,
        );
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp2,
          model: 'P100',
          deviceOn: false,
        );

        final stored = readDevices();
        expect(stored, hasLength(2));
        expect(stored[0]['ip'], TestFixtures.testDeviceIp);
        expect(stored[1]['ip'], TestFixtures.testDeviceIp2);
      });
    });

    group('saveAllDevices', () {
      test('saves list of devices', () async {
        final devices = [
          TestFixtures.onlineDevice(),
          TestFixtures.onlineDevice(
            ip: TestFixtures.testDeviceIp2,
            nickname: 'Plug 2',
            model: 'P100',
            deviceOn: false,
          ),
        ];

        await service.saveAllDevices(devices);

        final stored = readDevices();
        expect(stored, hasLength(2));
        expect(stored[0]['ip'], TestFixtures.testDeviceIp);
        expect(stored[0]['model'], 'P110');
        expect(stored[0]['deviceOn'], true);
        expect(stored[0]['isOnline'], true);
        expect(stored[1]['ip'], TestFixtures.testDeviceIp2);
        expect(stored[1]['model'], 'P100');
        expect(stored[1]['deviceOn'], false);
      });

      test('replaces existing data', () async {
        await service.saveAllDevices([TestFixtures.onlineDevice()]);

        await service.saveAllDevices([
          TestFixtures.offlineDevice(ip: TestFixtures.testDeviceIp2),
        ]);

        final stored = readDevices();
        expect(stored, hasLength(1));
        expect(stored[0]['ip'], TestFixtures.testDeviceIp2);
      });

      test('saves empty list', () async {
        await service.saveAllDevices([TestFixtures.onlineDevice()]);
        await service.saveAllDevices([]);

        final stored = readDevices();
        expect(stored, isEmpty);
      });

      test('includes offline device fields', () async {
        await service.saveAllDevices([TestFixtures.offlineDevice()]);

        final stored = readDevices();
        expect(stored[0]['isOnline'], false);
        expect(stored[0]['deviceOn'], false);
      });
    });

    group('clearWidgetData', () {
      test('removes devices key from store', () async {
        await service.saveAllDevices([TestFixtures.onlineDevice()]);
        expect(widgetStore.containsKey('devices'), isTrue);

        await service.clearWidgetData();

        expect(widgetStore.containsKey('devices'), isFalse);
      });

      test('is safe to call when no data exists', () async {
        await service.clearWidgetData();
        expect(widgetStore.containsKey('devices'), isFalse);
      });
    });

    group('saveDeviceState after saveAllDevices', () {
      test('appends to existing devices from saveAllDevices', () async {
        await service.saveAllDevices([TestFixtures.onlineDevice()]);
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp2,
          model: 'P100',
          deviceOn: true,
        );

        final stored = readDevices();
        expect(stored, hasLength(2));
      });

      test('updates device previously saved via saveAllDevices', () async {
        await service.saveAllDevices([TestFixtures.onlineDevice()]);
        await service.saveDeviceState(
          ip: TestFixtures.testDeviceIp,
          model: 'P110',
          deviceOn: false,
          isOnline: false,
        );

        final stored = readDevices();
        expect(stored, hasLength(1));
        expect(stored[0]['deviceOn'], false);
        expect(stored[0]['isOnline'], false);
      });
    });
  });
}
