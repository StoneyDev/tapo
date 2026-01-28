import 'package:flutter/material.dart';
import 'package:tapo/models/tapo_device.dart';

class PlugCard extends StatelessWidget {
  const PlugCard({
    required this.device,
    required this.onToggle,
    required this.onRemove,
    super.key,
    this.isToggling = false,
  });

  final TapoDevice device;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final bool isToggling;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(device.ip),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onRemove(),
      child: Card(
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
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer?'),
            content: Text('Supprimer ${device.nickname}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
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
    if (isToggling) {
      return const SizedBox(
        width: 48,
        height: 24,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Switch(
      value: device.deviceOn,
      onChanged: device.isOnline ? (_) => onToggle() : null,
    );
  }
}
