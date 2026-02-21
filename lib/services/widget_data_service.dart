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
    bool isOnline = true,
    String? nickname,
  }) async {
    final devices = await _readDevices();
    final index = devices.indexWhere((d) => d['ip'] == ip);
    final entry = {
      'ip': ip,
      'model': model,
      'nickname': nickname ?? model,
      'deviceOn': deviceOn,
      'isOnline': isOnline,
    };

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
            'nickname': d.nickname,
            'deviceOn': d.deviceOn,
            'isOnline': d.isOnline,
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

  /// Notify all home screen widgets to refresh their data.
  Future<void> refreshWidgets() => Future.wait([
        HomeWidget.updateWidget(
          androidName: 'TapoSingleWidgetProvider',
          iOSName: 'TapoWidget',
        ),
        HomeWidget.updateWidget(
          androidName: 'TapoListWidgetProvider',
          iOSName: 'TapoListWidget',
        ),
      ]);

  Future<void> _writeDevices(List<Map<String, dynamic>> devices) async {
    await HomeWidget.saveWidgetData<String>(_devicesKey, jsonEncode(devices));
  }
}
