import 'package:flutter/material.dart';
import 'package:tapo/models/tapo_device.dart';

// Building blocks shared by the mobile PlugCard and the desktop PlugTile.

String plugDisplayName(TapoDevice device) =>
    device.nickname.isNotEmpty ? device.nickname : 'Unknown Device';

/// Round badge telling whether the plug is on, off or offline.
class PlugStateIcon extends StatelessWidget {
  const PlugStateIcon({required this.device, super.key});

  final TapoDevice device;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch ((
      device.isOnline,
      device.deviceOn,
    )) {
      (false, _) => (colors.errorContainer, colors.error, Icons.power_off),
      (true, true) => (colors.secondaryContainer, Colors.green, Icons.power),
      (true, false) => (
        colors.surfaceContainerHighest,
        Colors.grey,
        Icons.power_off,
      ),
    };

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: foreground, size: 25),
    );
  }
}

/// "P110 • ALLUMÉE" line under the plug name.
class PlugSubtitle extends StatelessWidget {
  const PlugSubtitle({required this.device, super.key});

  final TapoDevice device;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = !device.isOnline
        ? 'HORS LIGNE'
        : device.deviceOn
        ? 'ALLUMÉE'
        : 'ÉTEINTE';
    final statusColor = !device.isOnline
        ? colors.error
        : device.deviceOn
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          device.model.isNotEmpty ? device.model : 'Tapo Plug',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: colors.outline,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Round power button: blue when the plug is on, spinner while toggling.
class PlugPowerButton extends StatelessWidget {
  const PlugPowerButton({
    required this.device,
    required this.onToggle,
    this.isToggling = false,
    super.key,
  });

  final TapoDevice device;
  final VoidCallback onToggle;
  final bool isToggling;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = device.isOnline && !isToggling;
    final background = device.deviceOn
        ? colors.primary
        : colors.surfaceContainerHighest;
    final foreground = device.deviceOn
        ? colors.onPrimary
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: enabled,
      label: device.deviceOn ? 'Éteindre la prise' : 'Allumer la prise',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 50,
        height: 50,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('power-${device.ip}'),
            customBorder: const CircleBorder(),
            focusColor: foreground.withValues(alpha: 0.24),
            hoverColor: foreground.withValues(alpha: 0.08),
            onTap: enabled ? onToggle : null,
            child: isToggling
                ? Padding(
                    padding: const EdgeInsets.all(15),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Icon(Icons.power_settings_new_rounded, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// "Éteindre dans 1 min" pill, or the running countdown that cancels on tap.
class PowerOffChip extends StatelessWidget {
  const PowerOffChip({
    required this.device,
    this.isToggling = false,
    this.remaining,
    this.onSchedule,
    this.onCancel,
    super.key,
  });

  final TapoDevice device;
  final bool isToggling;
  final Duration? remaining;
  final VoidCallback? onSchedule;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scheduled = remaining != null;
    final enabled =
        scheduled ||
        (device.isOnline &&
            device.deviceOn &&
            !isToggling &&
            onSchedule != null);
    final label = scheduled
        ? 'Arrêt dans ${_formatDuration(remaining!)}'
        : 'Éteindre dans 1 min';
    final foreground = scheduled
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: enabled,
      label: scheduled ? '$label, annuler' : label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.38,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: scheduled
                ? colors.secondaryContainer
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('countdown-${device.ip}'),
              borderRadius: BorderRadius.circular(24),
              onTap: !enabled
                  ? null
                  : scheduled
                  ? onCancel
                  : onSchedule,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      scheduled ? Icons.close_rounded : Icons.timer_outlined,
                      size: 15,
                      color: foreground,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = (duration.inMilliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
