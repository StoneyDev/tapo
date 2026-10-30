import 'package:flutter/material.dart';
import 'package:jolt/models/tapo_device.dart';
import 'package:jolt/views/widgets/plug_dialogs.dart';
import 'package:jolt/views/widgets/plug_parts.dart';

/// Mobile plug row: swipe to delete, long press to edit the IP.
class PlugCard extends StatelessWidget {
  const PlugCard({
    required this.device,
    required this.onToggle,
    required this.onRemove,
    required this.onEditIp,
    super.key,
    this.isToggling = false,
    this.powerOffRemaining,
    this.onSchedulePowerOff,
    this.onCancelPowerOff,
  });

  final TapoDevice device;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<String> onEditIp;
  final bool isToggling;
  final Duration? powerOffRemaining;
  final VoidCallback? onSchedulePowerOff;
  final VoidCallback? onCancelPowerOff;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(device.ip),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) => confirmPlugRemoval(context, device.nickname),
      onDismissed: (_) => onRemove(),
      child: GestureDetector(
        onLongPress: () => _editIp(context),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    PlugStateIcon(device: device),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDeviceInfo()),
                    const SizedBox(width: 12),
                    PlugPowerButton(
                      device: device,
                      isToggling: isToggling,
                      onToggle: onToggle,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.router_outlined,
                      size: 15,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        device.ip,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PowerOffChip(
                      device: device,
                      isToggling: isToggling,
                      remaining: powerOffRemaining,
                      onSchedule: onSchedulePowerOff,
                      onCancel: onCancelPowerOff,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plugDisplayName(device),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        PlugSubtitle(device: device),
      ],
    );
  }

  Future<void> _editIp(BuildContext context) async {
    final newIp = await showEditIpDialog(context, device.ip);
    if (newIp != null) onEditIp(newIp);
  }
}
