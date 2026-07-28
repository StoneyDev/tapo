import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:tapo/core/di.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/widget_callback.dart';
import 'package:tapo/views/config_screen.dart';
import 'package:tapo/views/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  unawaited(HomeWidget.setAppGroupId('group.stoneydev.tapo'));
  unawaited(HomeWidget.registerInteractivityCallback(widgetBackgroundCallback));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapo',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      darkTheme: darkAppTheme,
      home: const _StartupScreen(),
      routes: {
        '/config': (context) => const ConfigScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

final ThemeData appTheme = _buildAppTheme(Brightness.light);
final ThemeData darkAppTheme = _buildAppTheme(Brightness.dark);

ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark
      ? const ColorScheme.dark(
          primary: Color(0xFFC7FF5E),
          onPrimary: Color(0xFF141A18),
          secondary: Color(0xFFC7FF5E),
          onSecondary: Color(0xFF141A18),
          secondaryContainer: Color(0xFF31451E),
          onSecondaryContainer: Color(0xFFE5FFB3),
          error: Color(0xFFFF8A80),
          errorContainer: Color(0xFF5B1F1C),
          onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF171D1A),
          onSurface: Color(0xFFF4F5F0),
          onSurfaceVariant: Color(0xFFAEB7B1),
          outline: Color(0xFF7A837D),
          outlineVariant: Color(0xFF343B37),
          surfaceContainerHighest: Color(0xFF252C28),
        )
      : const ColorScheme.light(
          primary: Color(0xFF141A18),
          onPrimary: Color(0xFFC7FF5E),
          secondary: Color(0xFFC7FF5E),
          onSecondary: Color(0xFF141A18),
          secondaryContainer: Color(0xFFE5FFB3),
          onSecondaryContainer: Color(0xFF244500),
          error: Color(0xFFD4473F),
          errorContainer: Color(0xFFFFE1DD),
          onErrorContainer: Color(0xFF6A110D),
          onSurface: Color(0xFF141A18),
          onSurfaceVariant: Color(0xFF626965),
          outline: Color(0xFF9AA19D),
          outlineVariant: Color(0xFFE3E5DF),
          surfaceContainerHighest: Color(0xFFF0F1EC),
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF0F1412)
        : const Color(0xFFF5F2E9),
    textTheme: TextTheme(bodyMedium: TextStyle(color: colors.onSurface)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF202723) : const Color(0xFFF4F5F0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.onSurface, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
    ),
  );
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_checkAuth());
  }

  Future<void> _checkAuth() async {
    final storage = getIt<SecureStorageService>();
    final hasCreds = await storage.hasCredentials();

    if (!mounted) return;

    if (hasCreds) {
      final creds = await storage.getCredentials();
      await registerTapoService(creds.email!, creds.password!);
      if (!mounted) return;
      unawaited(Navigator.pushReplacementNamed(context, '/home'));
    } else {
      unawaited(Navigator.pushReplacementNamed(context, '/config'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 34,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'TAPO HOME',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
