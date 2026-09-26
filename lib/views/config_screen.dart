import 'dart:async';

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
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    final creds = await _viewModel.loadConfig();
    _emailController.text = creds.email;
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
    if (ip.isEmpty) return;
    _viewModel.addDeviceIp(ip);
    _ipController.clear();
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
      body: SafeArea(
        child: _viewModel.isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      Expanded(child: _buildForm(context)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.onSurface,
                child: Icon(
                  Icons.tune_rounded,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuration',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      'Compte et prises',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Compte Tapo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Adresse e-mail',
              fillColor: colors.surface,
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              fillColor: colors.surface,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            ),
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Vos prises',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_viewModel.deviceIps.length}',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ajoutez l’adresse IP de chaque prise sur votre Wi-Fi.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'Adresse IP',
                    hintText: '192.168.1.100',
                    fillColor: colors.surface,
                    prefixIcon: const Icon(Icons.router_outlined, size: 20),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addIp(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _addIp,
                tooltip: 'Ajouter la prise',
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                ),
              ),
            ],
          ),
          if (_viewModel.deviceIps.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final ip in _viewModel.deviceIps) ...[
              Row(
                children: [
                  Icon(
                    Icons.power_outlined,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ip,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: colors.onSurfaceVariant,
                    tooltip: 'Supprimer $ip',
                    onPressed: () => _viewModel.removeDeviceIp(ip),
                  ),
                ],
              ),
              Divider(height: 1, color: colors.outlineVariant),
            ],
          ],
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _viewModel.errorMessage!,
              style: TextStyle(color: colors.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Identifiants stockés sur cet appareil. '
                  'Contrôle sur le réseau local.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
