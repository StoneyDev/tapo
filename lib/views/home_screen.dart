import 'package:flutter/material.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
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
    _viewModel.loadDevices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _viewModel.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    watchIt<HomeViewModel>();
    final vm = _viewModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tapo Devices'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _buildBody(vm),
    );
  }

  Future<void> _logout(BuildContext context) async {
    // Disconnect all active sessions first
    final getIt = GetIt.instance;
    if (getIt.isRegistered<TapoService>()) {
      getIt<TapoService>().disconnectAll();
      getIt.unregister<TapoService>();
    }

    final storage = di<SecureStorageService>();
    await storage.clearCredentials();
    await storage.clearDeviceIps();
    if (context.mounted) {
      await Navigator.pushReplacementNamed(context, '/config');
    }
  }

  Widget _buildBody(HomeViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              vm.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: vm.refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (vm.devices.isEmpty) {
      return const Center(child: Text('No devices configured'));
    }

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: vm.devices.length,
        itemBuilder: (context, index) {
          final device = vm.devices[index];
          return PlugCard(
            device: device,
            onToggle: () => vm.toggleDevice(device.ip),
            onRemove: () => vm.removeDevice(device.ip),
            isToggling: vm.isToggling(device.ip),
          );
        },
      ),
    );
  }
}
