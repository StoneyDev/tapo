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
            : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configuration',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Connecter\nvotre maison.',
            style: TextStyle(
              fontSize: 38,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vos identifiants restent sur cet appareil. '
            'Les prises sont contrôlées sur votre réseau local.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Compte Tapo',
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Device IPs',
            subtitle: 'Ajoutez les prises présentes sur votre Wi-Fi.',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                          labelText: 'IP Address',
                          hintText: '192.168.1.100',
                          prefixIcon: Icon(Icons.router_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _addIp(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: _addIp,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(54, 54),
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                    ),
                  ],
                ),
                if (_viewModel.deviceIps.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (final ip in _viewModel.deviceIps)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ip,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Supprimer',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _viewModel.removeDeviceIp(ip),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _viewModel.errorMessage!,
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
