import 'package:flutter/material.dart';

import 'core/di.dart';
import 'views/config_screen.dart';

void main() {
  setupLocator();
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
      initialRoute: '/config',
      routes: {
        '/config': (context) => const ConfigScreen(),
        '/home': (context) => const Placeholder(), // TODO: US-015
      },
    );
  }
}
