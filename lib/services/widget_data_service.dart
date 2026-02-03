import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:tapo/models/tapo_device.dart';

/// Persists device state to home widget storage via home_widget package.
class WidgetDataService {
  static const _devicesKey = 'devices';

  /// Save a single device's state to widget storage.
  /// Updates existing entry by IP or adds new one.
  Future<void> saveDeviceState({
    required String ip,
    required String model,
    required bool deviceOn,
  }) async {
    final devices = await _readDevices();
    final index = devices.indexWhere((d) => d['ip'] == ip);
    final entry = {'ip': ip, 'model': model, 'deviceOn': deviceOn};

    if (index >= 0) {
      devices[index] = entry;
    } else {
      devices.add(entry);
    }

    await _writeDevices(devices);
  }

  /// Save all devices to widget storage, replacing existing data.
  Future<void> saveAllDevices(List<TapoDevice> deviceList) async {
    final devices = deviceList
        .map(
          (d) => {
            'ip': d.ip,
            'model': d.model,
            'deviceOn': d.deviceOn,
          },
        )
        .toList();
    await _writeDevices(devices);
  }

  /// Clear all widget data.
  Future<void> clearWidgetData() async {
    await HomeWidget.saveWidgetData<String>(_devicesKey, null);
  }

  Future<List<Map<String, dynamic>>> _readDevices() async {
    final json = await HomeWidget.getWidgetData<String>(_devicesKey);
    if (json == null) return [];
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> _writeDevices(List<Map<String, dynamic>> devices) async {
    await HomeWidget.saveWidgetData<String>(_devicesKey, jsonEncode(devices));
  }
}
