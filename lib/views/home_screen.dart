import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import '../viewmodels/home_viewmodel.dart';
import 'widgets/plug_card.dart';

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
        itemBuilder: (context, index) {
          final device = vm.devices[index];
          return PlugCard(
            device: device,
            onToggle: () => vm.toggleDevice(device.ip),
            isToggling: vm.isToggling(device.ip),
          );
        },
      ),
    );
  }
}
