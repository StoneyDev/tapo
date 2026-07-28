import 'package:flutter/material.dart';
import 'package:tapo/core/validators.dart';
import 'package:tapo/models/tapo_device.dart';

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
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onRemove(),
      child: GestureDetector(
        onLongPress: () => _showEditIpDialog(context),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStateIcon(colors),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDeviceInfo(context)),
                    const SizedBox(width: 12),
                    _buildPowerButton(colors),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.outlineVariant),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.router_outlined,
                      size: 15,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.ip,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    _buildCountdownButton(colors),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateIcon(ColorScheme colors) {
    final (background, foreground, icon) = switch ((
      device.isOnline,
      device.deviceOn,
    )) {
      (false, _) => (
        colors.errorContainer,
        colors.error,
        Icons.power_off,
      ),
      (true, true) => (
        colors.secondaryContainer,
        Colors.green,
        Icons.power,
      ),
      (true, false) => (
        colors.surfaceContainerHighest,
        Colors.grey,
        Icons.power_off,
      ),
    };

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(icon, color: foreground, size: 25),
    );
  }

  Widget _buildDeviceInfo(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          device.nickname.isNotEmpty ? device.nickname : 'Unknown Device',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Text(
              device.model.isNotEmpty ? device.model : 'Tapo Plug',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPowerButton(ColorScheme colors) {
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
      child: GestureDetector(
        key: ValueKey('power-${device.ip}'),
        onTap: enabled ? onToggle : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
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
    );
  }

  Widget _buildCountdownButton(ColorScheme colors) {
    final scheduled = powerOffRemaining != null;
    final enabled =
        scheduled ||
        (device.isOnline &&
            device.deviceOn &&
            !isToggling &&
            onSchedulePowerOff != null);
    final label = scheduled
        ? 'Arrêt dans ${_formatDuration(powerOffRemaining!)}'
        : 'Éteindre dans 1 min';

    return Semantics(
      button: true,
      enabled: enabled,
      label: scheduled ? '$label, annuler' : label,
      child: GestureDetector(
        key: ValueKey('countdown-${device.ip}'),
        onTap: !enabled
            ? null
            : scheduled
            ? onCancelPowerOff
            : onSchedulePowerOff,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.38,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheduled
                  ? colors.secondaryContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  scheduled ? Icons.close_rounded : Icons.timer_outlined,
                  size: 15,
                  color: scheduled
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: scheduled
                        ? colors.onSecondaryContainer
                        : colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = (duration.inMilliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showEditIpDialog(BuildContext context) async {
    final controller = TextEditingController(text: device.ip);
    final formKey = GlobalKey<FormState>();
    final newIp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier l'adresse IP"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Adresse IP',
              hintText: '192.168.1.100',
            ),
            validator: (value) {
              final ip = value?.trim() ?? '';
              if (ip.isEmpty) return 'Adresse IP requise';
              if (!isValidIpv4(ip)) return 'Format IP invalide';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (newIp != null && newIp != device.ip) {
      onEditIp(newIp);
    }
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
}
