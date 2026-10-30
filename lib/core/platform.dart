import 'package:flutter/foundation.dart';

/// Home screen widgets (home_widget) only exist on Android and iOS.
bool get supportsHomeWidgets =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Android widgets run Dart through home_widget's background callback; the
/// iOS widget intent starts its own engine on `widgetToggleMain` instead.
bool get usesWidgetBackgroundCallback =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The Windows runner provides the tray icon and the `tapo/desktop` channel.
bool get isWindowsDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Mouse-and-keyboard platforms: hover, context menus, no swipe gestures.
bool get isDesktopPlatform =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
