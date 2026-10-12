import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/views/desktop/desktop_sidebar.dart';
import 'package:tapo/views/desktop/plug_tile.dart';
import 'package:tapo/views/widgets/home_summary.dart';
import 'package:tapo/views/widgets/message_state.dart';

/// Sidebar + plug grid shown on wide windows.
class DesktopHomeLayout extends StatefulWidget {
  const DesktopHomeLayout({
    required this.viewModel,
    required this.onLogout,
    super.key,
  });

  final HomeViewModel viewModel;
  final VoidCallback onLogout;

  @override
  State<DesktopHomeLayout> createState() => _DesktopHomeLayoutState();
}

class _DesktopHomeLayoutState extends State<DesktopHomeLayout> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.viewModel.refresh(silent: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            unawaited(_refresh()),
      },
      child: Focus(
        autofocus: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopSidebar(
              viewModel: widget.viewModel,
              isRefreshing: _refreshing,
              onRefresh: () => unawaited(_refresh()),
              onLogout: widget.onLogout,
            ),
            Expanded(child: _PlugsPane(viewModel: widget.viewModel)),
          ],
        ),
      ),
    );
  }
}

class _PlugsPane extends StatelessWidget {
  const _PlugsPane({required this.viewModel});

  static const double _minTileWidth = 280;
  static const double _spacing = 16;

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 37, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DevicesHeader(count: viewModel.devices.length),
          const SizedBox(height: 24),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (viewModel.errorMessage != null) {
      return MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Connexion impossible',
        message: viewModel.errorMessage!,
        actionLabel: 'Retry',
        onAction: viewModel.refresh,
      );
    }

    final devices = viewModel.devices;
    if (devices.isEmpty) {
      return const MessageState(
        icon: Icons.power_outlined,
        title: 'No devices configured',
        message: 'Ajoutez une adresse IP depuis la configuration.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          (constraints.maxWidth + _spacing) ~/ (_minTileWidth + _spacing),
        );
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: PlugTile.height,
          ),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return PlugTile(
              key: ValueKey(device.ip),
              device: device,
              onToggle: () => viewModel.toggleDevice(device.ip),
              onRemove: () => viewModel.removeDevice(device.ip),
              onEditIp: (newIp) => viewModel.updateDeviceIp(device.ip, newIp),
              isToggling: viewModel.isToggling(device.ip),
              powerOffRemaining: viewModel.powerOffRemaining(device.ip),
              onSchedulePowerOff: () => viewModel.schedulePowerOff(device.ip),
              onCancelPowerOff: () => viewModel.cancelPowerOff(device.ip),
            );
          },
        );
      },
    );
  }
}
