import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolt/providers/home_provider.dart';
import 'package:jolt/views/desktop/desktop_sidebar.dart';
import 'package:jolt/views/desktop/plug_tile.dart';
import 'package:jolt/views/widgets/home_summary.dart';
import 'package:jolt/views/widgets/message_state.dart';
import 'package:jolt/views/widgets/plug_builder.dart';

/// Sidebar + plug grid shown on wide windows.
class DesktopHomeLayout extends ConsumerStatefulWidget {
  const DesktopHomeLayout({required this.onLogout, super.key});

  final VoidCallback onLogout;

  @override
  ConsumerState<DesktopHomeLayout> createState() => _DesktopHomeLayoutState();
}

class _DesktopHomeLayoutState extends ConsumerState<DesktopHomeLayout> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(homeProvider.notifier).refresh(silent: true);
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
              isRefreshing: _refreshing,
              onRefresh: () => unawaited(_refresh()),
              onLogout: widget.onLogout,
            ),
            const Expanded(child: _PlugsPane()),
          ],
        ),
      ),
    );
  }
}

class _PlugsPane extends ConsumerWidget {
  const _PlugsPane();

  static const double _minTileWidth = 280;
  static const double _spacing = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugs = ref.watch(plugListProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 37, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DevicesHeader(count: plugs.devices.length),
          const SizedBox(height: 24),
          Expanded(child: _buildBody(ref.read(homeProvider.notifier), plugs)),
        ],
      ),
    );
  }

  Widget _buildBody(HomeNotifier home, PlugList plugs) {
    final (:isLoading, :errorMessage, :devices) = plugs;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (errorMessage != null) {
      return MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Connexion impossible',
        message: errorMessage,
        actionLabel: 'Retry',
        onAction: home.refresh,
      );
    }

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
            final ip = devices[index].ip;
            return PlugBuilder(key: ValueKey(ip), ip: ip, card: PlugTile.new);
          },
        );
      },
    );
  }
}
