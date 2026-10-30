import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/providers/launch_at_startup_provider.dart';
import 'package:jolt/providers/services.dart';

import '../helpers/fake_desktop_shell.dart';

void main() {
  late FakeDesktopShell shell;
  late ProviderContainer container;

  setUp(() {
    shell = FakeDesktopShell();
    container = ProviderContainer.test(
      overrides: [desktopShellProvider.overrideWithValue(shell)],
    );
  });

  bool? isEnabled() => container.read(launchAtStartupProvider).value;

  group('LaunchAtStartupNotifier', () {
    test('reflects the runner state', () async {
      shell.launchAtStartup = true;

      expect(await container.read(launchAtStartupProvider.future), isTrue);
    });

    test('setEnabled persists the choice', () async {
      await container.read(launchAtStartupProvider.future);

      await container
          .read(launchAtStartupProvider.notifier)
          .setEnabled(enabled: true);

      expect(shell.launchAtStartup, isTrue);
      expect(isEnabled(), isTrue);
    });

    test('keeps the previous value when the runner fails', () async {
      await container.read(launchAtStartupProvider.future);
      shell.failLaunchAtStartupWrites = true;

      await container
          .read(launchAtStartupProvider.notifier)
          .setEnabled(enabled: true);

      expect(isEnabled(), isFalse);
    });
  });
}
