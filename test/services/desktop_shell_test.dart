import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/services/desktop_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('jolt/desktop');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late DesktopShell shell;

  setUp(() {
    calls = [];
    shell = DesktopShell();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'getLaunchAtStartup' ? null : true;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });

  Future<void> sendFromNative(String method, [Object? arguments]) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }

  group('DesktopShell', () {
    test('sends tray menu entries in the runner format', () async {
      await shell.showTrayMenu(const [
        TrayMenuItem(id: 7, label: 'Lampe', checked: true),
        TrayMenuSeparator(),
        TrayMenuItem(id: 8, label: 'Bureau — hors ligne', enabled: false),
      ]);

      expect(calls.single.method, 'showTrayMenu');
      expect(calls.single.arguments, [
        {'id': 7, 'label': 'Lampe', 'checked': true, 'enabled': true},
        {'separator': true},
        {
          'id': 8,
          'label': 'Bureau — hors ligne',
          'checked': false,
          'enabled': false,
        },
      ]);
    });

    test('sends notification title and message', () async {
      await shell.showNotification(title: 'Jolt', message: 'Injoignable');

      expect(calls.single.method, 'showNotification');
      expect(calls.single.arguments, {
        'title': 'Jolt',
        'message': 'Injoignable',
      });
    });

    test('treats a missing launch-at-startup answer as disabled', () async {
      expect(await shell.isLaunchAtStartupEnabled(), isFalse);
      expect(calls.single.method, 'getLaunchAtStartup');
    });

    test('routes native tray events to the handlers', () async {
      var menuRequests = 0;
      final selected = <int>[];
      shell.setTrayHandlers(
        onMenuRequested: () async => menuRequests++,
        onMenuItemSelected: (id) async => selected.add(id),
      );

      await sendFromNative('trayMenuRequested');
      await sendFromNative('trayMenuItemSelected', 42);

      expect(menuRequests, 1);
      expect(selected, [42]);
    });
  });
}
