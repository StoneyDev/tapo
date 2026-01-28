import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import '../models/tapo_device.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeScreen extends StatefulWidget with WatchItStatefulWidgetMixin {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = di<HomeViewModel>();
    _viewModel.loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    watchIt<HomeViewModel>();
    final vm = _viewModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tapo Devices'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(vm),
    );
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
            Text(vm.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: vm.refresh, child: const Text('Retry')),
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
        itemBuilder: (context, index) => _DeviceCard(
          device: vm.devices[index],
          onToggle: () => vm.toggleDevice(vm.devices[index].ip),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final TapoDevice device;
  final VoidCallback onToggle;

  const _DeviceCard({required this.device, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          device.deviceOn ? Icons.power : Icons.power_off,
          color: device.isOnline
              ? (device.deviceOn ? Colors.green : Colors.grey)
              : Colors.red,
          size: 32,
        ),
        title: Text(device.nickname.isNotEmpty ? device.nickname : device.ip),
        subtitle: Text('${device.model} • ${device.ip}'),
        trailing: Switch(
          value: device.deviceOn,
          onChanged: device.isOnline ? (_) => onToggle() : null,
        ),
      ),
    );
  }
}
