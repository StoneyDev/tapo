import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapo/core/platform.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/providers/home_provider.dart';
import 'package:tapo/views/desktop/desktop_breakpoint.dart';
import 'package:tapo/views/desktop/desktop_home_layout.dart';
import 'package:tapo/views/widgets/home_summary.dart';
import 'package:tapo/views/widgets/message_state.dart';
import 'package:tapo/views/widgets/plug_builder.dart';
import 'package:tapo/views/widgets/plug_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final home = ref.read(homeProvider.notifier);
    // Desktop windows resume on every focus gain: only refresh stale data.
    unawaited(
      isDesktopPlatform
          ? home.refreshIfStale(const Duration(seconds: 30))
          : home.refresh(),
    );
  }

  void _logout() => unawaited(ref.read(homeProvider.notifier).logout());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= desktopBreakpoint) {
              return DesktopHomeLayout(onLogout: _logout);
            }
            return Column(
              children: [
                _buildHeader(context),
                const Expanded(child: _PlugList()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: colors.onSurface,
            child: Icon(
              Icons.home_rounded,
              color: Theme.of(context).scaffoldBackgroundColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ma maison',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.7,
                  ),
                ),
                Text(
                  'Tapo · chez vous',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Se déconnecter',
            child: IconButton(
              icon: const Icon(Icons.logout, size: 21),
              tooltip: 'Logout',
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outlineVariant),
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlugList extends ConsumerWidget {
  const _PlugList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:isLoading, :errorMessage, :devices) = ref.watch(plugListProvider);
    final home = ref.read(homeProvider.notifier);

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

    return RefreshIndicator(
      onRefresh: home.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: devices.length + 1,
        separatorBuilder: (context, index) => index == 0
            ? const SizedBox.shrink()
            : Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
        itemBuilder: (context, index) {
          if (index == 0) return _buildOverview(devices);
          return PlugBuilder(ip: devices[index - 1].ip, card: PlugCard.new);
        },
      ),
    );
  }

  Widget _buildOverview(List<TapoDevice> devices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        PoweredSummary(devices: devices),
        const SizedBox(height: 30),
        DevicesHeader(count: devices.length),
        const SizedBox(height: 8),
      ],
    );
  }
}
