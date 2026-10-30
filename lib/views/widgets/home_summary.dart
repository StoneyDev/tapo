import 'package:flutter/material.dart';
import 'package:jolt/models/tapo_device.dart';

/// "Prises allumées 01 / 03" counter with the local network status.
class PoweredSummary extends StatelessWidget {
  const PoweredSummary({required this.devices, super.key});

  final List<TapoDevice> devices;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final online = devices.where((device) => device.isOnline).length;
    final connectionColor = online > 0
        ? colors.secondary
        : colors.onSurfaceVariant;
    final powered = devices
        .where((device) => device.isOnline && device.deviceOn)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prises allumées',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: powered.toString().padLeft(2, '0')),
              TextSpan(
                text: ' / ${devices.length.toString().padLeft(2, '0')}',
                style: TextStyle(color: colors.outline, fontSize: 36),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 68,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -3,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              online > 0 ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              size: 18,
              color: connectionColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$online en ligne · réseau local',
                style: TextStyle(
                  color: connectionColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Prises" section title with the device count pill.
class DevicesHeader extends StatelessWidget {
  const DevicesHeader({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Prises',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            '$count appareil${count > 1 ? 's' : ''}',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
