import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/main.dart' show appTheme, darkAppTheme;
import 'package:jolt/models/tapo_device.dart';
import 'package:jolt/providers/home_provider.dart';
import 'package:jolt/providers/services.dart';
import 'package:jolt/views/config_screen.dart';
import 'package:jolt/views/home_screen.dart';
import 'package:mockito/mockito.dart';

import '../helpers/fake_desktop_shell.dart';
import '../helpers/test_utils.mocks.dart';
import 'home_test_doubles.dart';

const _devices = [
  TapoDevice(
    ip: '192.168.1.10',
    nickname: 'Lampe Salon',
    model: 'P110',
    deviceOn: true,
    isOnline: true,
  ),
  TapoDevice(
    ip: '192.168.1.11',
    nickname: 'Bureau',
    model: 'P100',
    deviceOn: false,
    isOnline: true,
  ),
  TapoDevice(
    ip: '192.168.1.12',
    nickname: 'Chambre',
    model: 'P110',
    deviceOn: false,
    isOnline: false,
  ),
];

/// Windows renders with the compact density of desktop platforms.
ThemeData _desktop(ThemeData theme) => theme.copyWith(
  platform: TargetPlatform.windows,
  visualDensity: VisualDensity.compact,
);

const _desktopSize = Size(1000, 660);

/// The configuration form with a stored account and two plugs.
Override _storedConfig() {
  final storage = MockSecureStorageService();
  when(
    storage.getCredentials(),
  ).thenAnswer((_) async => (email: 'user@example.com', password: null));
  when(
    storage.getDeviceIps(),
  ).thenAnswer((_) async => ['192.168.1.10', '192.168.1.11']);
  return secureStorageProvider.overrideWithValue(storage);
}

void main() {
  // Build the themes before any platform override so they keep the test
  // fonts (Segoe UI, the Windows default, is not available in tests).
  setUpAll(() => [appTheme, darkAppTheme]);

  group('golden', () {
    testWidgets('home screen with devices', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWith(
              () => FakeHomeNotifier.withDevices(_devices),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_screen.png'),
      );
    });

    testWidgets('config screen with IPs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_storedConfig()],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme,
            home: const ConfigScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/config_screen.png'),
      );
    });

    for (final (name, theme) in [('light', appTheme), ('dark', darkAppTheme)]) {
      testWidgets('desktop home screen ($name)', (tester) async {
        await tester.binding.setSurfaceSize(_desktopSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeProvider.overrideWith(
                () => FakeHomeNotifier.withDevices(_devices),
              ),
              desktopShellProvider.overrideWithValue(
                FakeDesktopShell()..launchAtStartup = true,
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _desktop(theme),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/desktop_home_$name.png'),
        );
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }

    testWidgets('desktop config screen', (tester) async {
      await tester.binding.setSurfaceSize(_desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_storedConfig()],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _desktop(appTheme),
            home: const ConfigScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop_config_screen.png'),
      );
    });
  });
}
