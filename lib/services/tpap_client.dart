import 'package:jolt/core/tpap_session.dart';

/// Client for Tapo devices via TPAP protocol (firmware 1.4+)
class TpapClient {
  TpapClient({required this.session});

  final TpapSession session;

  Future<Map<String, dynamic>?> getDeviceInfo() async {
    final response = await session.request({'method': 'get_device_info'});
    if (response == null) return null;
    return response['result'] as Map<String, dynamic>?;
  }

  Future<bool> setDeviceOn({required bool on}) async {
    final response = await session.request({
      'method': 'set_device_info',
      'params': {'device_on': on},
    });
    return response != null;
  }

  /// Has the plug turn itself off after [delay], replacing its countdown: it
  /// holds a single one.
  Future<bool> setPowerOffCountdown(Duration delay) async {
    await clearCountdown();
    final response = await session.request({
      'method': 'add_countdown_rule',
      'params': {
        'delay': delay.inSeconds,
        'desired_states': {'on': false},
        'enable': true,
        'remain': delay.inSeconds,
      },
    });
    return response != null;
  }

  Future<bool> clearCountdown() async {
    final response = await session.request({
      'method': 'remove_countdown_rules',
      'params': {'remove_all': true},
    });
    return response != null;
  }

  Future<Map<String, dynamic>?> getEnergyUsage() async {
    final response = await session.request({'method': 'get_energy_usage'});
    if (response == null) return null;
    return response['result'] as Map<String, dynamic>?;
  }
}
