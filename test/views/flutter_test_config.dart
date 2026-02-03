import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadMaterialFonts();
  await testMain();
}

Future<void> _loadMaterialFonts() async {
  final flutterRoot = _findFlutterRoot();
  if (flutterRoot == null) return;

  final fontsDir = '$flutterRoot/bin/cache/artifacts/material_fonts';

  await _loadFont('Roboto', '$fontsDir/Roboto-Regular.ttf');
  await _loadFont('MaterialIcons', '$fontsDir/MaterialIcons-Regular.otf');
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;

  final loader = FontLoader(family);
  final bytes = await file.readAsBytes();
  loader.addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

String? _findFlutterRoot() {
  // Resolve via FLUTTER_ROOT env or walk up from dart executable
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && Directory(env).existsSync()) return env;

  // Walk up from Dart SDK to find Flutter root
  var dir = Directory(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    if (File('${dir.path}/bin/flutter').existsSync()) return dir.path;
    dir = dir.parent;
  }
  return null;
}
