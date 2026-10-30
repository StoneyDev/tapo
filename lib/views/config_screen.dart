import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolt/providers/config_provider.dart';
import 'package:jolt/views/desktop/desktop_breakpoint.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _ipController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  ConfigNotifier get _config => ref.read(configProvider.notifier);

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
    _config.addDeviceIp(ip);
    _ipController.clear();
  }

  // Signing in switches the app to the home screen.
  void _save() => unawaited(
    _config.saveConfig(_emailController.text.trim(), _passwordController.text),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(configProvider.select((config) => config.value?.email), (
      _,
      email,
    ) {
      if (email != null) _emailController.text = email;
    });
    final config = ref.watch(configProvider).value;

    return Scaffold(
      body: SafeArea(
        child: config == null || config.isSaving
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= desktopBreakpoint
                    ? _buildCard(context, config)
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: _buildContent(context, config, inCard: false),
                        ),
                      ),
              ),
      ),
    );
  }

  /// Wide windows: the form sits in a card on the page background.
  Widget _buildCard(BuildContext context, ConfigState config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildContent(context, config, inCard: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ConfigState config, {
    required bool inCard,
  }) {
    return Column(
      children: [
        Expanded(child: _buildForm(context, config, inCard: inCard)),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: FilledButton(
            onPressed: _save,
            child: const Text('Enregistrer'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(
    BuildContext context,
    ConfigState config, {
    required bool inCard,
  }) {
    final colors = Theme.of(context).colorScheme;
    // On the surface-colored card, fields keep the theme's contrasting fill.
    final fieldFill = inCard ? null : colors.surface;
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
              fillColor: fieldFill,
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
              fillColor: fieldFill,
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
                '${config.deviceIps.length}',
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
                    fillColor: fieldFill,
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
          if (config.deviceIps.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final ip in config.deviceIps) ...[
              Row(
                children: [
                  Icon(
                    Icons.power_outlined,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(ip, style: const TextStyle(fontSize: 14)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: colors.onSurfaceVariant,
                    tooltip: 'Supprimer $ip',
                    onPressed: () => _config.removeDeviceIp(ip),
                  ),
                ],
              ),
              Divider(height: 1, color: colors.outlineVariant),
            ],
          ],
          if (config.errorMessage case final errorMessage?) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage,
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
