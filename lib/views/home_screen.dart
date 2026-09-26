import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/views/widgets/plug_card.dart';
import 'package:watch_it/watch_it.dart';

class HomeScreen extends StatefulWidget with WatchItStatefulWidgetMixin {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = di<HomeViewModel>();
    unawaited(_viewModel.loadDevices());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_viewModel.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    watchIt<HomeViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody()),
          ],
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
              onPressed: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final devices = _viewModel.devices;
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
        const SizedBox(height: 26),
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
        const SizedBox(height: 30),
        Row(
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
                '${devices.length} appareil${devices.length > 1 ? 's' : ''}',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_viewModel.errorMessage != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Connexion impossible',
        message: _viewModel.errorMessage!,
        actionLabel: 'Retry',
        onAction: _viewModel.refresh,
      );
    }

    if (_viewModel.devices.isEmpty) {
      return const _MessageState(
        icon: Icons.power_outlined,
        title: 'No devices configured',
        message: 'Ajoutez une adresse IP depuis la configuration.',
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _viewModel.devices.length + 1,
        separatorBuilder: (context, index) => index == 0
            ? const SizedBox.shrink()
            : Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
        itemBuilder: (context, index) {
          if (index == 0) return _buildOverview(context);
          final device = _viewModel.devices[index - 1];
          return PlugCard(
            device: device,
            onToggle: () => _viewModel.toggleDevice(device.ip),
            onRemove: () => _viewModel.removeDevice(device.ip),
            onEditIp: (newIp) => _viewModel.updateDeviceIp(device.ip, newIp),
            isToggling: _viewModel.isToggling(device.ip),
            powerOffRemaining: _viewModel.powerOffRemaining(device.ip),
            onSchedulePowerOff: () => _viewModel.schedulePowerOff(device.ip),
            onCancelPowerOff: () => _viewModel.cancelPowerOff(device.ip),
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    _viewModel.cancelAllPowerOffs();
    final locator = GetIt.instance;
    if (locator.isRegistered<TapoService>()) {
      await locator<TapoService>().disconnectAll();
      await locator.unregister<TapoService>();
    }

    final storage = di<SecureStorageService>();
    await storage.clearCredentials();
    await storage.clearDeviceIps();

    final widgetData = di<WidgetDataService>();
    await widgetData.clearWidgetData();
    await widgetData.refreshWidgets();

    if (context.mounted) {
      await Navigator.pushReplacementNamed(context, '/config');
    }
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: colors.onSurfaceVariant, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
