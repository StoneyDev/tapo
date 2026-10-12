import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';
import 'package:tapo/views/home_screen.dart';
import 'package:tapo/views/widgets/plug_card.dart';

import '../helpers/test_utils.dart';
import 'home_test_doubles.dart';

void main() {
  late MockHomeViewModel mockViewModel;
  late MockSecureStorageService mockStorageService;
  late MockTapoService mockTapoService;
  late MockWidgetDataService mockWidgetDataService;
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
    mockViewModel = MockHomeViewModel();
    mockStorageService = MockSecureStorageService();
    mockTapoService = MockTapoService();
    mockWidgetDataService = MockWidgetDataService();

    getIt
      ..registerSingleton<HomeViewModel>(mockViewModel)
      ..registerSingleton<SecureStorageService>(mockStorageService)
      ..registerSingleton<TapoService>(mockTapoService)
      ..registerSingleton<WidgetDataService>(mockWidgetDataService);
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// Phone-sized app: these tests cover the mobile layout.
  Widget buildTestWidget({bool withNavigation = false}) {
    Widget phone(BuildContext context, Widget? child) =>
        Center(child: SizedBox(width: 400, child: child));

    if (withNavigation) {
      return MaterialApp(
        builder: phone,
        initialRoute: '/home',
        routes: {
          '/home': (_) => const HomeScreen(),
          '/config': (_) => const Scaffold(body: Text('Config Screen')),
        },
      );
    }
    return MaterialApp(builder: phone, home: const HomeScreen());
  }

  group('HomeScreen', () {
    group('loading state', () {
      testWidgets('shows spinner when loading, hides otherwise', (
        tester,
      ) async {
        mockViewModel.setIsLoading(loading: true);
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        mockViewModel
          ..setIsLoading(loading: false)
          ..setDevices([]);
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('device list', () {
      testWidgets('renders PlugCards for each device', (tester) async {
        mockViewModel.setDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1', nickname: 'Device 1'),
          TestFixtures.onlineDevice(ip: '10.0.0.2', nickname: 'Device 2'),
        ]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(PlugCard), findsNWidgets(2));
        expect(find.text('Device 1'), findsOneWidget);
        expect(find.text('Device 2'), findsOneWidget);
      });

      testWidgets('displays empty state message when no devices', (
        tester,
      ) async {
        mockViewModel.setDevices([]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('No devices configured'), findsOneWidget);
      });

      testWidgets('displays error message with retry button', (tester) async {
        mockViewModel.setErrorMessage('Connection failed');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Connection failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('retry button calls refresh', (tester) async {
        mockViewModel.setErrorMessage('Error');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(mockViewModel.refreshCallCount, 1);
      });
    });

    group('pull to refresh', () {
      testWidgets('pull down triggers refresh', (tester) async {
        mockViewModel.setDevices([TestFixtures.onlineDevice(ip: '10.0.0.1')]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Perform pull to refresh
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pumpAndSettle();

        expect(mockViewModel.refreshCallCount, 1);
      });
    });

    group('logout', () {
      testWidgets('clears credentials, disconnects, navigates', (tester) async {
        mockViewModel.setDevices([]);
        await tester.pumpWidget(buildTestWidget(withNavigation: true));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.logout), findsOneWidget);

        await tester.tap(find.byIcon(Icons.logout));
        await tester.pumpAndSettle();

        expect(mockStorageService.clearCredentialsCallCount, 1);
        expect(mockStorageService.clearDeviceIpsCallCount, 1);
        expect(mockTapoService.disconnectAllCallCount, 1);
        expect(mockWidgetDataService.clearWidgetDataCallCount, 1);
        expect(mockWidgetDataService.refreshWidgetsCallCount, 1);
        expect(find.text('Config Screen'), findsOneWidget);
      });
    });

    group('device interactions', () {
      testWidgets('device toggle triggers toggleDevice', (tester) async {
        mockViewModel.setDevices([
          TestFixtures.onlineDevice(ip: '10.0.0.1', deviceOn: false),
        ]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('power-10.0.0.1')));
        await tester.pump();

        expect(mockViewModel.toggleDeviceCallCount, 1);
        expect(mockViewModel.lastToggledIp, '10.0.0.1');
      });

      testWidgets('isToggling state passed to PlugCard', (tester) async {
        mockViewModel
          ..setDevices([TestFixtures.onlineDevice(ip: '10.0.0.1')])
          ..setToggling('10.0.0.1', toggling: true);
        await tester.pumpWidget(buildTestWidget());
        // Use pump() instead of pumpAndSettle()
        // because CircularProgressIndicator animates
        await tester.pump();

        // When toggling, PlugCard shows spinner
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byKey(const ValueKey('power-10.0.0.1')), findsOneWidget);
      });
    });

    group('app lifecycle', () {
      testWidgets('app resume triggers refresh', (tester) async {
        mockViewModel.setDevices([]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Reset count since loadDevices called in init
        mockViewModel.refreshCallCount = 0;

        // Simulate app resume
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(mockViewModel.refreshCallCount, 1);
      });
    });

    group('initialization', () {
      testWidgets('renders title and calls loadDevices', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.text('Ma maison'), findsOneWidget);
        expect(mockViewModel.loadDevicesCallCount, 1);
      });
    });
  });
}
