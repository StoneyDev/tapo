import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/services/widget_callback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> widgetStore;
  late Map<String, String?> secureStore;
  late List<MethodCall> homeWidgetCalls;

  void setupChannelMocks() {
    homeWidgetCalls = [];

    // Mock home_widget MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (
          MethodCall call,
        ) async {
          homeWidgetCalls.add(call);
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
          (MethodCall call) async {
            switch (call.method) {
              case 'read':
                final args = call.arguments as Map;
                final key = args['key'] as String;
                return secureStore[key];
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
    secureStore = {};
    setupChannelMocks();
  });

  tearDown(clearChannelMocks);

  group('widgetBackgroundCallback', () {
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
          Uri.parse('tapotoggle://wronghost?ip=192.168.1.1'),
        );
        expect(homeWidgetCalls, isEmpty);
      });

      test('returns when ip param is missing', () async {
        await widgetBackgroundCallback(Uri.parse('tapotoggle://toggle'));
        expect(homeWidgetCalls, isEmpty);
      });

      test('returns when ip param is empty', () async {
        await widgetBackgroundCallback(Uri.parse('tapotoggle://toggle?ip='));
        expect(homeWidgetCalls, isEmpty);
      });
    });

    group('credential guard clauses', () {
      test('calls setAppGroupId before checking creds', () async {
        await widgetBackgroundCallback(
          Uri.parse('tapotoggle://toggle?ip=192.168.1.100'),
        );

        final methods = homeWidgetCalls.map((c) => c.method).toList();
        expect(methods, contains('setAppGroupId'));
      });

      test('returns when no credentials stored', () async {
        await widgetBackgroundCallback(
          Uri.parse('tapotoggle://toggle?ip=192.168.1.100'),
        );

        final methods = homeWidgetCalls.map((c) => c.method).toList();
        expect(methods, isNot(contains('updateWidget')));
        expect(methods, isNot(contains('saveWidgetData')));
      });

      test('returns when only email is stored', () async {
        secureStore['tapo_email'] = 'test@example.com';

        await widgetBackgroundCallback(
          Uri.parse('tapotoggle://toggle?ip=192.168.1.100'),
        );

        final methods = homeWidgetCalls.map((c) => c.method).toList();
        expect(methods, isNot(contains('updateWidget')));
      });

      test('returns when only password is stored', () async {
        secureStore['tapo_password'] = 'password123';

        await widgetBackgroundCallback(
          Uri.parse('tapotoggle://toggle?ip=192.168.1.100'),
        );

        final methods = homeWidgetCalls.map((c) => c.method).toList();
        expect(methods, isNot(contains('updateWidget')));
      });
    });
  });
}
