import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';

/// Background callback for home widget interactivity.
/// Runs in a separate isolate -- must bootstrap services independently.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  if (uri.scheme != 'tapotoggle' || uri.host != 'toggle') return;

  final ip = uri.queryParameters['ip'];
  if (ip == null || ip.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId('group.stoneydev.tapo');

  final storage = SecureStorageService();
  final creds = await storage.getCredentials();
  if (creds.email == null || creds.password == null) return;

  final tapoService = TapoService.fromCredentials(
    creds.email!,
    creds.password!,
  );
  final widgetData = WidgetDataService();

  final currentDevice = await _findDeviceByIp(ip);

  try {
    final device = await tapoService.toggleDevice(ip);
    await widgetData.saveDeviceState(
      ip: device.ip,
      model: device.model,
      deviceOn: device.deviceOn,
      isOnline: device.isOnline,
    );
  } on Exception {
    await widgetData.saveDeviceState(
      ip: ip,
      model: currentDevice?['model'] as String? ?? 'Unknown',
      deviceOn: currentDevice?['deviceOn'] as bool? ?? false,
      isOnline: false,
    );
  }

  await _refreshAllWidgets();
}

Future<Map<String, dynamic>?> _findDeviceByIp(String ip) async {
  final json = await HomeWidget.getWidgetData<String>('devices');
  if (json == null) return null;
  final devices = (jsonDecode(json) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return devices.where((d) => d['ip'] == ip).firstOrNull;
}

Future<void> _refreshAllWidgets() => Future.wait([
      HomeWidget.updateWidget(
        androidName: 'TapoSingleWidgetProvider',
        iOSName: 'TapoWidget',
      ),
      HomeWidget.updateWidget(
        androidName: 'TapoListWidgetProvider',
        iOSName: 'TapoListWidget',
      ),
    ]);
