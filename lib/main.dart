import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:tapo/core/di.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/widget_callback.dart';
import 'package:tapo/views/config_screen.dart';
import 'package:tapo/views/home_screen.dart';

void main() {
  setupLocator();
  HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const _StartupScreen(),
      routes: {
        '/config': (context) => const ConfigScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
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
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final storage = getIt<SecureStorageService>();
    final hasCreds = await storage.hasCredentials();

    if (!mounted) return;

    if (hasCreds) {
      final creds = await storage.getCredentials();
      if (!mounted) return;
      registerTapoService(creds.email!, creds.password!);
      unawaited(Navigator.pushReplacementNamed(context, '/home'));
    } else {
      unawaited(Navigator.pushReplacementNamed(context, '/config'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
