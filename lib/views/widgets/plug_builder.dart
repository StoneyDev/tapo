import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolt/models/tapo_device.dart';
import 'package:jolt/providers/home_provider.dart';

/// The constructor shared by PlugCard (mobile) and PlugTile (desktop).
typedef PlugWidget =
    Widget Function({
      required TapoDevice device,
      required VoidCallback onToggle,
      required VoidCallback onRemove,
      required ValueChanged<String> onEditIp,
      bool isToggling,
      Duration? powerOffRemaining,
      VoidCallback? onSchedulePowerOff,
      VoidCallback? onCancelPowerOff,
    });

/// Builds the [card] of the plug at [ip], wired to [homeProvider]. Rebuilt
/// only when that plug changes: a countdown tick does not rebuild the list.
class PlugBuilder extends ConsumerWidget {
  const PlugBuilder({required this.ip, required this.card, super.key});

  final String ip;
  final PlugWidget card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plug = ref.watch(plugProvider(ip));
    // Removed: the list drops this card on its next build.
    if (plug == null) return const SizedBox.shrink();

    final home = ref.read(homeProvider.notifier);
    return card(
      device: plug.device,
      onToggle: () => home.toggleDevice(ip),
      onRemove: () => home.removeDevice(ip),
      onEditIp: (newIp) => home.updateDeviceIp(ip, newIp),
      isToggling: plug.isToggling,
      powerOffRemaining: plug.powerOffRemaining,
      onSchedulePowerOff: () => home.schedulePowerOff(ip),
      onCancelPowerOff: () => home.cancelPowerOff(ip),
    );
  }
}
