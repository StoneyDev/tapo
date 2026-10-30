import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/services/widget_callback.dart';

import '../helpers/fake_plugs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> widgetStore;
  late Map<String, String?> secureStore;
  late List<MethodCall> homeWidgetCalls;
  var secureStorageUnavailable = false;
  var deviceWritesUnavailable = false;

  void setupChannelMocks() {
    homeWidgetCalls = [];

    // Mock home_widget MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (
          call,
        ) async {
          homeWidgetCalls.add(call);
          switch (call.method) {
            case 'saveWidgetData':
              final args = call.arguments as Map;
              final id = args['id'] as String;
              final data = args['data'];
              if (id == 'devices' && deviceWritesUnavailable) {
                throw PlatformException(code: 'storage_unavailable');
              }
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
            case 'setAppGroupId':
              return true;
            case 'updateWidget':
              return true;
            default:
              return null;
          }
        });

    // Mock flutter_secure_storage MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            switch (call.method) {
              case 'read':
                if (secureStorageUnavailable) {
                  throw PlatformException(code: 'storage_unavailable');
                }
                final args = call.arguments as Map;
                return secureStore[args['key'] as String];
              case 'write':
                final args = call.arguments as Map;
                secureStore[args['key'] as String] = args['value'] as String?;
                return null;
              default:
                return null;
            }
          },
        );
  }

  void clearChannelMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  }

  setUp(() {
    widgetStore = {};
    secureStore = {
      'tapo_device_ips': jsonEncode(['192.168.1.100']),
    };
    secureStorageUnavailable = false;
    deviceWritesUnavailable = false;
    setupChannelMocks();
  });

  tearDown(clearChannelMocks);

  group('widgetBackgroundCallback', () {
    test('clears loading after 10 seconds when connection hangs', () async {
      const ip = '192.168.1.100';
      secureStore.addAll({
        'tapo_email': 'test@example.com',
        'tapo_password': 'password123',
      });
      widgetStore.addAll({
        'loading_$ip': true,
        'devices': jsonEncode([
          {
            'ip': ip,
            'model': 'P110',
            'nickname': 'Desk',
            'deviceOn': true,
            'isOnline': true,
          },
        ]),
      });

      final completed = await IOOverrides.runZoned(
        () => widgetBackgroundCallback(Uri.parse('jolttoggle://toggle?ip=$ip'))
            .then((_) => true)
            .timeout(const Duration(seconds: 11), onTimeout: () => false),
        socketConnect: (host, port, {sourceAddress, sourcePort = 0, timeout}) =>
            Completer<Socket>().future,
      );

      expect(completed, isTrue);
      expect(widgetStore.containsKey('loading_$ip'), isFalse);
      final devices = jsonDecode(widgetStore['devices'] as String) as List;
      expect(devices.single, {
        'ip': ip,
        'model': 'P110',
        'nickname': 'Desk',
        'deviceOn': true,
        'isOnline': false,
      });
      expect(
        homeWidgetCalls.where((call) => call.method == 'updateWidget'),
        hasLength(2),
      );
    });

    test('clears loading when reading credentials fails', () async {
      secureStorageUnavailable = true;
      widgetStore['loading_192.168.1.100'] = true;

      await widgetBackgroundCallback(
        Uri.parse('jolttoggle://toggle?ip=192.168.1.100'),
      );

      expect(widgetStore.containsKey('loading_192.168.1.100'), isFalse);
      expect(
        homeWidgetCalls.where((call) => call.method == 'updateWidget'),
        hasLength(2),
      );
    });

    test('keeps the plug name when secure storage is unavailable', () async {
      secureStorageUnavailable = true;
      widgetStore['devices'] = jsonEncode([
        {
          'ip': '192.168.1.100',
          'model': 'P110',
          'nickname': 'Desk',
          'deviceOn': true,
          'isOnline': true,
        },
      ]);

      await widgetBackgroundCallback(
        Uri.parse('jolttoggle://toggle?ip=192.168.1.100'),
      );

      final devices = jsonDecode(widgetStore['devices'] as String) as List;
      expect(devices.single, {
        'ip': '192.168.1.100',
        'model': 'P110',
        'nickname': 'Desk',
        'deviceOn': true,
        'isOnline': false,
      });
    });

    test('clears loading even if saving the offline state fails', () async {
      secureStorageUnavailable = true;
      deviceWritesUnavailable = true;
      widgetStore['loading_192.168.1.100'] = true;

      await expectLater(
        widgetBackgroundCallback(
          Uri.parse('jolttoggle://toggle?ip=192.168.1.100'),
        ),
        throwsA(isA<PlatformException>()),
      );

      expect(widgetStore.containsKey('loading_192.168.1.100'), isFalse);
      expect(
        homeWidgetCalls.where((call) => call.method == 'updateWidget'),
        hasLength(2),
      );
    });

    group('URI guard clauses', () {
      test('returns immediately for null uri', () async {
        await widgetBackgroundCallback(null);
        expect(homeWidgetCalls, isEmpty);
      });

      test('returns for wrong scheme', () async {
        await widgetBackgroundCallback(
          Uri.parse('http://toggle?ip=192.168.1.1'),
        );
        expect(homeWidgetCalls, isEmpty);
      });

      test('returns for wrong host', () async {
        await widgetBackgroundCallback(
          Uri.parse('jolttoggle://wronghost?ip=192.168.1.1'),
        );
        expect(homeWidgetCalls, isEmpty);
      });

      test('returns when ip param is missing', () async {
        await widgetBackgroundCallback(Uri.parse('jolttoggle://toggle'));
        expect(homeWidgetCalls, isEmpty);
      });
    });

    for (final ip in ['192.168.1.200', 'attacker.example', '']) {
      test('ignores "$ip", which is not a configured plug', () async {
        secureStore.addAll({
          'tapo_email': 'test@example.com',
          'tapo_password': 'password123',
        });
        widgetStore['loading_$ip'] = true;
        final hosts = <Object?>[];

        await IOOverrides.runZoned(
          () => HttpOverrides.runZoned(
            () => widgetBackgroundCallback(
              Uri.parse('jolttoggle://toggle?ip=$ip'),
            ),
            createHttpClient: FakeTpapPlug().createClient,
          ),
          socketConnect:
              (host, port, {sourceAddress, sourcePort = 0, timeout}) {
                hosts.add(host);
                return (FakeKlapPlug()..port = PortState.refused).connect(
                  timeout,
                );
              },
        );

        expect(hosts, isEmpty);
        expect(widgetStore['devices'], isNull);
        expect(widgetStore.containsKey('loading_$ip'), isFalse);
      });
    }

    group('credential guard clauses', () {
      test('calls setAppGroupId before checking creds', () async {
        await widgetBackgroundCallback(
          Uri.parse('jolttoggle://toggle?ip=192.168.1.100'),
        );

        final methods = homeWidgetCalls.map((c) => c.method).toList();
        expect(methods, contains('setAppGroupId'));
      });

      test(
        'clears loading and refreshes widgets when no credentials',
        () async {
          await widgetBackgroundCallback(
            Uri.parse('jolttoggle://toggle?ip=192.168.1.100'),
          );

          final methods = homeWidgetCalls.map((c) => c.method).toList();
          expect(methods, contains('saveWidgetData'));
          expect(methods, contains('updateWidget'));
        },
      );

      test('clears loading and refreshes when only email is stored', () async {
        secureStore['tapo_email'] = 'test@example.com';

        await widgetBackgroundCallback(
          Uri.parse('jolttoggle://toggle?ip=192.168.1.100'),
        );

        final methods = homeWidgetCalls.map((c) => c.method).toList();
        expect(methods, contains('updateWidget'));
      });

      test(
        'clears loading and refreshes when only password is stored',
        () async {
          secureStore['tapo_password'] = 'password123';

          await widgetBackgroundCallback(
            Uri.parse('jolttoggle://toggle?ip=192.168.1.100'),
          );

          final methods = homeWidgetCalls.map((c) => c.method).toList();
          expect(methods, contains('updateWidget'));
        },
      );
    });
  });

  group('widgetToggleMain', () {
    const toggleChannel = MethodChannel('jolt/widget_toggle');
    // Not a configured plug: the toggle stops early but still clears loading.
    const ip = '192.168.1.200';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<bool> loadingAtDone;

    setUp(() {
      loadingAtDone = [];
      messenger.setMockMethodCallHandler(toggleChannel, (call) async {
        if (call.method == 'done') {
          loadingAtDone.add(widgetStore.containsKey('loading_$ip'));
        }
        return null;
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(toggleChannel, null));

    test('reports done once the toggle has cleared loading', () async {
      widgetStore['loading_$ip'] = true;

      await widgetToggleMain([ip]);

      expect(loadingAtDone, [false]);
    });

    test('reports done when the toggle fails', () async {
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (call) async => throw PlatformException(code: 'unavailable'),
      );

      await expectLater(
        widgetToggleMain([ip]),
        throwsA(isA<PlatformException>()),
      );
      expect(loadingAtDone, hasLength(1));
    });
  });
}
