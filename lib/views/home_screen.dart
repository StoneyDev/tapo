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
    final online = _viewModel.devices.where((device) => device.isOnline).length;
    final powered = _viewModel.devices
        .where((device) => device.isOnline && device.deviceOn)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: colors.onSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'TAPO HOME',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Se déconnecter',
                child: IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  tooltip: 'Logout',
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.onSurface,
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  onPressed: () => _logout(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Prises',
                  style: TextStyle(
                    fontSize: 38,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.8,
                  ),
                ),
              ),
              if (_viewModel.devices.isNotEmpty)
                Text(
                  '$powered allumée${powered > 1 ? 's' : ''}\n'
                  '$online en ligne',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
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
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _viewModel.devices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final device = _viewModel.devices[index];
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
