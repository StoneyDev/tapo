import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import '../viewmodels/config_viewmodel.dart';

class ConfigScreen extends StatefulWidget with WatchItStatefulWidgetMixin {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _ipController = TextEditingController();
  late final ConfigViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = di<ConfigViewModel>();
    _viewModel.loadConfig();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _addIp() {
    final ip = _ipController.text.trim();
    if (ip.isNotEmpty) {
      _viewModel.addDeviceIp(ip);
      _ipController.clear();
    }
  }

  Future<void> _save() async {
    final success = await _viewModel.saveConfig();
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    watchIt<ConfigViewModel>();
    final vm = _viewModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(vm),
    );
  }

  Widget _buildForm(ConfigViewModel vm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            controller: TextEditingController(text: vm.email),
            onChanged: (v) => vm.email = v,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            controller: TextEditingController(text: vm.password),
            onChanged: (v) => vm.password = v,
          ),
          const SizedBox(height: 24),
          const Text('Device IPs', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    border: OutlineInputBorder(),
                    hintText: '192.168.1.100',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addIp,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...vm.deviceIps.map((ip) => ListTile(
                title: Text(ip),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => vm.removeDeviceIp(ip),
                ),
              )),
          if (vm.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              vm.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
