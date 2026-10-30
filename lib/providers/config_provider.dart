import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jolt/core/validators.dart';
import 'package:jolt/providers/auth_provider.dart';
import 'package:jolt/providers/services.dart';

part 'config_provider.freezed.dart';

@freezed
abstract class ConfigState with _$ConfigState {
  const factory ConfigState({
    /// Stored email, to prefill the form.
    @Default('') String email,
    @Default(<String>[]) List<String> deviceIps,
    @Default(false) bool isSaving,
    String? errorMessage,
  }) = _ConfigState;
}

/// The configuration form, from the stored account and plugs.
final AsyncNotifierProvider<ConfigNotifier, ConfigState> configProvider =
    AsyncNotifierProvider.autoDispose(ConfigNotifier.new);

class ConfigNotifier extends AsyncNotifier<ConfigState> {
  @override
  Future<ConfigState> build() async {
    final storage = ref.read(secureStorageProvider);
    try {
      final creds = await storage.getCredentials();
      final deviceIps = await storage.getDeviceIps();
      return ConfigState(email: creds.email ?? '', deviceIps: deviceIps);
    } on Exception {
      return const ConfigState(errorMessage: 'Failed to load configuration');
    }
  }

  ConfigState get _config => state.value ?? const ConfigState();

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  /// Saves the plugs, then signs in: the app switches to the home screen.
  Future<void> saveConfig(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      return _setError('Email and password required');
    }
    if (!_isValidEmail(email)) return _setError('Invalid email format');
    if (password.length < 8) {
      return _setError('Password must be at least 8 characters');
    }

    final config = _config;
    state = AsyncData(config.copyWith(isSaving: true, errorMessage: null));

    try {
      await ref.read(secureStorageProvider).saveDeviceIps(config.deviceIps);
      await ref.read(authProvider.notifier).login(email, password);
      if (ref.mounted) state = AsyncData(config.copyWith(errorMessage: null));
    } on Exception {
      if (ref.mounted) _setError('Failed to save configuration');
    }
  }

  void addDeviceIp(String ip) {
    final trimmedIp = ip.trim();
    final config = _config;

    if (trimmedIp.isEmpty) {
      _setError('IP address cannot be empty');
    } else if (!isValidIpv4(trimmedIp)) {
      _setError('Invalid IP address format');
    } else if (config.deviceIps.contains(trimmedIp)) {
      _setError('IP address already added');
    } else {
      state = AsyncData(
        config.copyWith(
          deviceIps: [...config.deviceIps, trimmedIp],
          errorMessage: null,
        ),
      );
    }
  }

  void _setError(String message) {
    state = AsyncData(_config.copyWith(isSaving: false, errorMessage: message));
  }

  void removeDeviceIp(String ip) {
    final config = _config;
    state = AsyncData(
      config.copyWith(
        deviceIps: [
          for (final deviceIp in config.deviceIps)
            if (deviceIp != ip) deviceIp,
        ],
      ),
    );
  }
}
