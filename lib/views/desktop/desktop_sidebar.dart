import 'package:flutter/material.dart';
import 'package:tapo/core/platform.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/viewmodels/launch_at_startup_viewmodel.dart';
import 'package:tapo/views/widgets/home_summary.dart';
import 'package:watch_it/watch_it.dart';

/// Left column of the desktop layout: summary, global actions and settings.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    required this.viewModel,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onLogout,
    super.key,
  });

  static const double width = 320;

  final HomeViewModel viewModel;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final devices = viewModel.devices;
    final anyOn = devices.any((device) => device.isOnline && device.deviceOn);

    // A Material (not a DecoratedBox) so the setting tiles can paint ink.
    return Material(
      color: colors.surface,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary scrolls on short windows; actions stay reachable.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    const SizedBox(height: 40),
                    PoweredSummary(devices: devices),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: anyOn ? viewModel.turnOffAll : null,
                    icon: const Icon(Icons.power_settings_new_rounded),
                    label: const Text('Tout éteindre'),
                  ),
                  const SizedBox(height: 10),
                  _RefreshButton(
                    isRefreshing: isRefreshing,
                    onPressed: onRefresh,
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: colors.outlineVariant),
                  const SizedBox(height: 8),
                  if (isWindowsDesktop) const _LaunchAtStartupTile(),
                  _SettingTile(
                    icon: Icons.logout,
                    label: 'Se déconnecter',
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
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
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.isRefreshing, required this.onPressed});

  final bool isRefreshing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        foregroundColor: colors.onSurface,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: isRefreshing
                ? const Padding(
                    padding: EdgeInsets.all(1),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Actualiser', overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'F5',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchAtStartupTile extends WatchingWidget {
  const _LaunchAtStartupTile();

  @override
  Widget build(BuildContext context) {
    final launchAtStartup = watchIt<LaunchAtStartupViewModel>();
    return _SettingTile(
      icon: Icons.rocket_launch_outlined,
      label: 'Lancer au démarrage',
      onTap: () =>
          launchAtStartup.setEnabled(enabled: !launchAtStartup.isEnabled),
      // Compact toggle, close to the Windows 11 switch size.
      trailing: SizedBox(
        height: 24,
        child: FittedBox(
          child: Switch(
            value: launchAtStartup.isEnabled,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (enabled) =>
                launchAtStartup.setEnabled(enabled: enabled),
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
