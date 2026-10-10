import 'package:flutter_test/flutter_test.dart';
import 'package:tapo/viewmodels/launch_at_startup_viewmodel.dart';

import '../helpers/fake_desktop_shell.dart';

void main() {
  late FakeDesktopShell shell;
  late LaunchAtStartupViewModel viewModel;

  setUp(() {
    shell = FakeDesktopShell();
    viewModel = LaunchAtStartupViewModel(shell: shell);
  });

  tearDown(() => viewModel.dispose());

  group('LaunchAtStartupViewModel', () {
    test('load reflects the runner state', () async {
      shell.launchAtStartup = true;

      await viewModel.load();

      expect(viewModel.isEnabled, isTrue);
    });

    test('setEnabled persists the choice and notifies', () async {
      var notified = 0;
      viewModel.addListener(() => notified++);

      await viewModel.setEnabled(enabled: true);

      expect(shell.launchAtStartup, isTrue);
      expect(viewModel.isEnabled, isTrue);
      expect(notified, greaterThan(0));
    });

    test('keeps the previous value when the runner fails', () async {
      shell.failLaunchAtStartupWrites = true;

      await viewModel.setEnabled(enabled: true);

      expect(viewModel.isEnabled, isFalse);
    });
  });
}
