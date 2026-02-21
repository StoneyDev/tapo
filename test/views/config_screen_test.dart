import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';
import 'package:tapo/views/config_screen.dart';

import '../helpers/test_utils.dart';

/// Mock ConfigViewModel for widget testing
/// Note: This tests UI behavior in response to ViewModel state
/// changes. The actual ViewModel logic is tested in
/// config_viewmodel_test.dart.
class MockConfigViewModel extends ChangeNotifier implements ConfigViewModel {
  List<String> _deviceIps = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  List<String> get deviceIps => List.unmodifiable(_deviceIps);
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;

  // State setters for test setup
  void setDeviceIps(List<String> ips) {
    _deviceIps = ips;
    notifyListeners();
  }

  void setIsLoading({required bool loading}) {
    _isLoading = loading;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Call tracking
  int addDeviceIpCallCount = 0;
  String? lastAddedIp;
  int removeDeviceIpCallCount = 0;
  String? lastRemovedIp;
  int loadConfigCallCount = 0;
  int saveConfigCallCount = 0;
  String? lastSaveEmail;
  String? lastSavePassword;

  // Return values
  ({String email, String password})? loadConfigReturn;
  bool saveConfigReturn = true;

  @override
  void addDeviceIp(String ip) {
    addDeviceIpCallCount++;
    lastAddedIp = ip;
    if (ip.isNotEmpty && !_deviceIps.contains(ip)) {
      _deviceIps = [..._deviceIps, ip];
      notifyListeners();
    }
  }

  @override
  void removeDeviceIp(String ip) {
    removeDeviceIpCallCount++;
    lastRemovedIp = ip;
    _deviceIps = _deviceIps.where((i) => i != ip).toList();
    notifyListeners();
  }

  @override
  Future<({String email, String password})> loadConfig() async {
    loadConfigCallCount++;
    return loadConfigReturn ?? (email: '', password: '');
  }

  @override
  Future<bool> saveConfig(String email, String password) async {
    saveConfigCallCount++;
    lastSaveEmail = email;
    lastSavePassword = password;
    return saveConfigReturn;
  }
}

void main() {
  late MockConfigViewModel mockViewModel;
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
    mockViewModel = MockConfigViewModel();
    getIt.registerSingleton<ConfigViewModel>(mockViewModel);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildTestWidget({bool withNavigation = false}) {
    if (withNavigation) {
      return MaterialApp(
        initialRoute: '/config',
        routes: {
          '/config': (_) => const ConfigScreen(),
          '/home': (_) => const Scaffold(body: Text('Home Screen')),
        },
      );
    }
    return const MaterialApp(home: ConfigScreen());
  }

  group('ConfigScreen', () {
    group('form fields render', () {
      testWidgets('renders all form fields and populates email', (
        tester,
      ) async {
        mockViewModel.loadConfigReturn = (
          email: TestFixtures.testEmail,
          password: '',
        );
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'IP Address'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
        expect(find.text('Device IPs'), findsOneWidget);
        expect(find.text(TestFixtures.testEmail), findsOneWidget);
      });
    });

    group('add IP button', () {
      testWidgets('add button is rendered', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('tapping add button calls addDeviceIp', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Enter IP in the IP field
        await tester.enterText(
          find.widgetWithText(TextField, 'IP Address'),
          TestFixtures.testDeviceIp,
        );
        await tester.pump();

        // Tap add button
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(mockViewModel.addDeviceIpCallCount, 1);
        expect(mockViewModel.lastAddedIp, TestFixtures.testDeviceIp);
      });

      testWidgets('clears IP field after adding', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final ipFieldFinder = find.widgetWithText(TextField, 'IP Address');
        await tester.enterText(ipFieldFinder, TestFixtures.testDeviceIp);
        await tester.pump();

        // Tap add button
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Field should be cleared
        final textField = tester.widget<TextField>(ipFieldFinder);
        expect(textField.controller?.text, '');
      });

      testWidgets('does not call addDeviceIp when IP field empty', (
        tester,
      ) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap add without entering IP
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(mockViewModel.addDeviceIpCallCount, 0);
      });

      testWidgets('added IP appears in list', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Use IP different from hint text '192.168.1.100'
        const addedIp = '10.0.0.50';

        // Enter and add IP
        await tester.enterText(
          find.widgetWithText(TextField, 'IP Address'),
          addedIp,
        );
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // IP should appear in list
        expect(find.text(addedIp), findsOneWidget);
      });
    });

    group('delete button removes IP', () {
      // Use IPs different from hint text '192.168.1.100'
      const testIp1 = '10.0.0.1';
      const testIp2 = '10.0.0.2';

      testWidgets('delete button is shown for each IP', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..setDeviceIps([testIp1, testIp2]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Should have 2 delete buttons
        expect(find.byIcon(Icons.delete), findsNWidgets(2));
      });

      testWidgets('tapping delete calls removeDeviceIp', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..setDeviceIps([testIp1]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Verify IP is displayed in list
        expect(find.text(testIp1), findsOneWidget);

        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        expect(mockViewModel.removeDeviceIpCallCount, 1);
        expect(mockViewModel.lastRemovedIp, testIp1);
      });

      testWidgets('removed IP no longer appears in list', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..setDeviceIps([testIp1]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // IP is visible initially in list
        expect(find.text(testIp1), findsOneWidget);

        // Tap delete
        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        // IP should be gone from list
        expect(find.text(testIp1), findsNothing);
      });
    });

    group('save validates and navigates on success', () {
      testWidgets('save calls saveConfig with credentials', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..saveConfigReturn = true;
        await tester.pumpWidget(buildTestWidget(withNavigation: true));
        await tester.pumpAndSettle();

        // Enter email and password
        await tester.enterText(
          find.widgetWithText(TextField, 'Email'),
          TestFixtures.testEmail,
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          TestFixtures.testPassword,
        );
        await tester.pump();

        // Tap save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(mockViewModel.saveConfigCallCount, 1);
        expect(mockViewModel.lastSaveEmail, TestFixtures.testEmail);
        expect(mockViewModel.lastSavePassword, TestFixtures.testPassword);
      });

      testWidgets('navigates to /home on successful save', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..saveConfigReturn = true;
        await tester.pumpWidget(buildTestWidget(withNavigation: true));
        await tester.pumpAndSettle();

        // Enter email and password
        await tester.enterText(
          find.widgetWithText(TextField, 'Email'),
          TestFixtures.testEmail,
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          TestFixtures.testPassword,
        );
        await tester.pump();

        // Tap save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Should be on home screen
        expect(find.text('Home Screen'), findsOneWidget);
      });

      testWidgets('does not navigate when save returns false', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..saveConfigReturn = false;
        await tester.pumpWidget(buildTestWidget(withNavigation: true));
        await tester.pumpAndSettle();

        // Enter email and password
        await tester.enterText(
          find.widgetWithText(TextField, 'Email'),
          TestFixtures.testEmail,
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          TestFixtures.testPassword,
        );
        await tester.pump();

        // Tap save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Should still be on config screen
        expect(find.text('Configuration'), findsOneWidget);
        expect(find.text('Home Screen'), findsNothing);
      });
    });

    group('error message displays', () {
      testWidgets('displays error message with styling when set', (
        tester,
      ) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..setErrorMessage('Test error');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Test error'), findsOneWidget);
        final errorText = tester.widget<Text>(find.text('Test error'));
        expect(errorText.style?.color, isNotNull);
      });

      testWidgets('hides error message when null', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..setErrorMessage(null);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Error'), findsNothing);
      });
    });

    group('loading state', () {
      testWidgets('shows spinner and hides form when loading', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..setIsLoading(loading: true);
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Email'), findsNothing);
        expect(find.text('Password'), findsNothing);
      });

      testWidgets('shows form when not loading', (tester) async {
        mockViewModel
          ..loadConfigReturn = (email: '', password: '')
          ..setIsLoading(loading: false);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('initialization', () {
      testWidgets('renders title and calls loadConfig', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Configuration'), findsOneWidget);
        expect(mockViewModel.loadConfigCallCount, 1);
      });
    });
  });
}
