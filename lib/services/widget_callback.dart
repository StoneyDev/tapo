import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';

/// Background callback for home widget interactivity.
/// Runs in a separate isolate - must bootstrap services independently.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  if (uri.scheme != 'tapotoggle' || uri.host != 'toggle') return;

  final ip = uri.queryParameters['ip'];
  if (ip == null || ip.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();

  // Read credentials from secure storage (no DI in background isolate)
  final storage = SecureStorageService();
  final creds = await storage.getCredentials();
  if (creds.email == null || creds.password == null) return;

  // Create TapoService and toggle device
  final tapoService =
      TapoService.fromCredentials(creds.email!, creds.password!);
  final device = await tapoService.toggleDevice(ip);

  // Update widget data optimistically
  final widgetData = WidgetDataService();
  await widgetData.saveDeviceState(
    ip: device.ip,
    model: device.model,
    deviceOn: device.deviceOn,
  );

  // Refresh native widgets
  await HomeWidget.updateWidget(
    androidName: 'TapoSingleWidgetProvider',
    iOSName: 'TapoWidget',
  );
  await HomeWidget.updateWidget(
    androidName: 'TapoListWidgetProvider',
    iOSName: 'TapoListWidget',
  );
}
