import 'dart:convert';

import 'package:flutter/services.dart';
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
  if (ip == null) return;
  await _toggleFromWidget(ip);
}

/// Entry point of the engine the iOS widget intent starts to toggle the plug
/// at `args.single`. The intent waits for `done`, so every path must send it.
@pragma('vm:entry-point')
Future<void> widgetToggleMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _toggleFromWidget(args.single);
  } finally {
    await const MethodChannel('tapo/widget_toggle').invokeMethod<void>('done');
  }
}

Future<void> _toggleFromWidget(String ip) async {
  // The widget set loading_$ip for any value: every path below must clear it.

  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId('group.dev.yannderoues.tapo');

  final widgetData = WidgetDataService();
  final storage = SecureStorageService();
  TapoService? tapoService;
  Map<String, dynamic>? currentDevice;

  try {
    currentDevice = await _findDeviceByIp(ip);
    // Credentials only ever go to plugs the user configured.
    if (!(await storage.getDeviceIps()).contains(ip)) return;
    final creds = await storage.getCredentials();
    if (creds.email == null || creds.password == null) return;

    tapoService = TapoService.fromCredentials(creds.email!, creds.password!);
    final device = await tapoService
        .toggleDevice(ip)
        .timeout(const Duration(seconds: 10));
    await widgetData.saveDeviceState(
      ip: device.ip,
      model: device.model,
      nickname: device.nickname,
      deviceOn: device.deviceOn,
      isOnline: device.isOnline,
    );
  } on Exception {
    await widgetData.saveDeviceState(
      ip: ip,
      model: currentDevice?['model'] as String? ?? 'Unknown',
      nickname: currentDevice?['nickname'] as String?,
      deviceOn: currentDevice?['deviceOn'] as bool? ?? false,
      isOnline: false,
    );
  } finally {
    await HomeWidget.saveWidgetData('loading_$ip', null);
    await widgetData.refreshWidgets();
    await tapoService?.disconnectAll();
  }
}

Future<Map<String, dynamic>?> _findDeviceByIp(String ip) async {
  final json = await HomeWidget.getWidgetData<String>('devices');
  if (json == null) return null;
  try {
    final devices = (jsonDecode(json) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return devices.where((d) => d['ip'] == ip).firstOrNull;
  } on FormatException {
    return null;
  }
}
