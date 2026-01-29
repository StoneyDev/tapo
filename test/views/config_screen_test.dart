import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/viewmodels/config_viewmodel.dart';
import 'package:tapo/views/config_screen.dart';

import '../helpers/test_utils.dart';

/// Mock ConfigViewModel for testing
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

  // Mock control methods
  void setDeviceIps(List<String> ips) {
    _deviceIps = ips;
    notifyListeners();
  }

  void setIsLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Tracked method calls for verification
  int addDeviceIpCallCount = 0;
  String? lastAddedIp;

  int removeDeviceIpCallCount = 0;
  String? lastRemovedIp;

  int loadConfigCallCount = 0;
  ({String email, String password})? loadConfigReturn;

  int saveConfigCallCount = 0;
  String? lastSaveEmail;
  String? lastSavePassword;
  bool saveConfigReturn = true;

  @override
  void addDeviceIp(String ip) {
    addDeviceIpCallCount++;
    lastAddedIp = ip;
    // Simulate adding to list
    if (!_deviceIps.contains(ip) && ip.isNotEmpty) {
      _deviceIps = [..._deviceIps, ip];
      _errorMessage = null;
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
    return const MaterialApp(
      home: ConfigScreen(),
    );
  }

  group('ConfigScreen', () {
    group('form fields render', () {
      testWidgets('renders email field', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      });

      testWidgets('renders password field', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      });

      testWidgets('renders IP address field', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'IP Address'), findsOneWidget);
      });

      testWidgets('renders Save button', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      });

      testWidgets('renders Device IPs label', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Device IPs'), findsOneWidget);
      });

      testWidgets('populates email from loadConfig', (tester) async {
        mockViewModel.loadConfigReturn = (email: TestFixtures.testEmail, password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

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

      testWidgets('tapping add button calls addDeviceIp with entered IP', (tester) async {
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

        // Find the IP TextField controller
        final ipFieldFinder = find.widgetWithText(TextField, 'IP Address');
        await tester.enterText(ipFieldFinder, TestFixtures.testDeviceIp);
        await tester.pump();

        // Tap add button
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // The field should be cleared (no text with IP should remain in TextField)
        final textField = tester.widget<TextField>(ipFieldFinder);
        expect(textField.controller?.text, '');
      });

      testWidgets('does not call addDeviceIp when IP field is empty', (tester) async {
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
      // Use IPs different from the hint text '192.168.1.100'
      const testIp1 = '10.0.0.1';
      const testIp2 = '10.0.0.2';

      testWidgets('delete button is shown for each IP', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setDeviceIps([testIp1, testIp2]);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Should have 2 delete buttons (one for each IP)
        expect(find.byIcon(Icons.delete), findsNWidgets(2));
      });

      testWidgets('tapping delete calls removeDeviceIp with correct IP', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setDeviceIps([testIp1]);
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
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setDeviceIps([testIp1]);
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
      testWidgets('save calls saveConfig with entered credentials', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.saveConfigReturn = true;
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
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.saveConfigReturn = true;
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
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.saveConfigReturn = false;
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
      testWidgets('error message is displayed when set', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setErrorMessage('Test error message');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Test error message'), findsOneWidget);
      });

      testWidgets('error message has error color', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setErrorMessage('Error');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final errorText = tester.widget<Text>(find.text('Error'));
        expect(errorText.style?.color, isNotNull);
      });

      testWidgets('no error message shown when null', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setErrorMessage(null);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // No Text widget with typical error messages
        expect(find.text('Error'), findsNothing);
        expect(find.text('Invalid'), findsNothing);
      });
    });

    group('loading state', () {
      testWidgets('shows loading indicator when isLoading is true', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setIsLoading(true);
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('hides form when isLoading is true', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setIsLoading(true);
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        // Form fields should not be visible
        expect(find.text('Email'), findsNothing);
        expect(find.text('Password'), findsNothing);
      });

      testWidgets('shows form when isLoading is false', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        mockViewModel.setIsLoading(false);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Form should be visible
        expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('app bar', () {
      testWidgets('renders app bar with Configuration title', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Configuration'), findsOneWidget);
      });
    });

    group('loadConfig on init', () {
      testWidgets('calls loadConfig on initialization', (tester) async {
        mockViewModel.loadConfigReturn = (email: '', password: '');
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(mockViewModel.loadConfigCallCount, 1);
      });
    });
  });
}
