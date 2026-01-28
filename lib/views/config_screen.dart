import 'package:flutter/material.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';
import 'package:watch_it/watch_it.dart';

class ConfigScreen extends StatefulWidget with WatchItStatefulWidgetMixin {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _ipController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final ConfigViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = di<ConfigViewModel>();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final creds = await _viewModel.loadConfig();
    _emailController.text = creds.email;
    // Don't pre-populate password for security - require re-entry
  }

  @override
  void dispose() {
    _ipController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
    final success = await _viewModel.saveConfig(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (success && mounted) {
      await Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    watchIt<ConfigViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          const Text(
            'Device IPs',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
          for (final ip in _viewModel.deviceIps)
            ListTile(
              title: Text(ip),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _viewModel.removeDeviceIp(ip),
              ),
            ),
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _viewModel.errorMessage!,
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
