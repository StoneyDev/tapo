import 'package:flutter/material.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/views/widgets/plug_dialogs.dart';
import 'package:tapo/views/widgets/plug_parts.dart';

enum _TileAction { editIp, remove }

/// Desktop plug card: hover outline, "⋯" button and right-click menu.
class PlugTile extends StatefulWidget {
  const PlugTile({
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

  /// Height that fits the tile content.
  static const double height = 204;

  final TapoDevice device;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<String> onEditIp;
  final bool isToggling;
  final Duration? powerOffRemaining;
  final VoidCallback? onSchedulePowerOff;
  final VoidCallback? onCancelPowerOff;

  @override
  State<PlugTile> createState() => _PlugTileState();
}

class _PlugTileState extends State<PlugTile> {
  bool _hovered = false;

  TapoDevice get _device => widget.device;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _openMenu(details.globalPosition & Size.zero),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hovered ? colors.outline : colors.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PlugStateIcon(device: _device),
                  const Spacer(),
                  Builder(
                    builder: (buttonContext) => IconButton(
                      tooltip: 'Options',
                      icon: const Icon(Icons.more_horiz_rounded),
                      color: colors.onSurfaceVariant,
                      onPressed: () => _openMenu(_globalRect(buttonContext)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PlugPowerButton(
                    device: _device,
                    isToggling: widget.isToggling,
                    onToggle: widget.onToggle,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                plugDisplayName(_device),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              PlugSubtitle(device: _device),
              const Spacer(),
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
                      _device.ip,
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
                    device: _device,
                    isToggling: widget.isToggling,
                    remaining: widget.powerOffRemaining,
                    onSchedule: widget.onSchedulePowerOff,
                    onCancel: widget.onCancelPowerOff,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Rect _globalRect(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Opens the plug menu next to [anchor] (global coordinates).
  Future<void> _openMenu(Rect anchor) async {
    final colors = Theme.of(context).colorScheme;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<_TileAction>(
      context: context,
      position: RelativeRect.fromRect(
        overlay.globalToLocal(anchor.topLeft) & anchor.size,
        Offset.zero & overlay.size,
      ),
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        const PopupMenuItem(
          value: _TileAction.editIp,
          child: _MenuRow(icon: Icons.edit_outlined, label: "Modifier l'IP"),
        ),
        PopupMenuItem(
          value: _TileAction.remove,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Supprimer',
            color: colors.error,
          ),
        ),
      ],
    );
    if (!mounted) return;

    switch (action) {
      case _TileAction.editIp:
        final newIp = await showEditIpDialog(context, _device.ip);
        if (newIp != null) widget.onEditIp(newIp);
      case _TileAction.remove:
        if (await confirmPlugRemoval(context, _device.nickname)) {
          widget.onRemove();
        }
      case null:
        break;
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }
}
