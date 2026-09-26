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
          primary: Color(0xFF4D5BFF),
          onPrimary: Colors.white,
          secondary: Color(0xFF32D75A),
          onSecondary: Color(0xFF001B08),
          secondaryContainer: Color(0xFF102B18),
          onSecondaryContainer: Color(0xFF32D75A),
          error: Color(0xFFFF515D),
          errorContainer: Color(0xFF321417),
          onErrorContainer: Color(0xFFFFB3BA),
          onSurface: Color(0xFFF7F7F7),
          onSurfaceVariant: Color(0xFF999999),
          outline: Color(0xFF737373),
          outlineVariant: Color(0xFF262626),
          surfaceContainerHighest: Color(0xFF242424),
        )
      : const ColorScheme.light(
          primary: Color(0xFF3948FF),
          secondary: Color(0xFF138A35),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFE2F6E7),
          onSecondaryContainer: Color(0xFF138A35),
          error: Color(0xFFD82D40),
          errorContainer: Color(0xFFFFE8EB),
          onErrorContainer: Color(0xFF8A1726),
          onSurface: Color(0xFF101010),
          onSurfaceVariant: Color(0xFF6D6D6D),
          outline: Color(0xFF929292),
          outlineVariant: Color(0xFFE0E0E0),
          surfaceContainerHighest: Color(0xFFEAEAEA),
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: isDark ? Colors.black : const Color(0xFFF3F3F1),
    textTheme: TextTheme(bodyMedium: TextStyle(color: colors.onSurface)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF3F3F1),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
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
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/config');
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
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 34,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'TAPO HOME',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
