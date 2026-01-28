import 'package:flutter/material.dart';
import '../../models/tapo_device.dart';

class PlugCard extends StatelessWidget {
  final TapoDevice device;
  final VoidCallback onToggle;

  const PlugCard({super.key, required this.device, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildStateIcon(colorScheme),
            const SizedBox(width: 16),
            Expanded(child: _buildDeviceInfo()),
            _buildToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateIcon(ColorScheme colorScheme) {
    final Color iconColor;
    final IconData iconData;

    if (!device.isOnline) {
      iconColor = colorScheme.error;
      iconData = Icons.power_off;
    } else if (device.deviceOn) {
      iconColor = Colors.green;
      iconData = Icons.power;
    } else {
      iconColor = Colors.grey;
      iconData = Icons.power_off;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: iconColor, size: 28),
    );
  }

  Widget _buildDeviceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          device.nickname.isNotEmpty ? device.nickname : 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          device.model.isNotEmpty ? device.model : 'Tapo Plug',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        Text(
          device.ip,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildToggle() {
    return Switch(
      value: device.deviceOn,
      onChanged: device.isOnline ? (_) => onToggle() : null,
    );
  }
}
