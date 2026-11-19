import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app group the iOS app shares with its widgets: the dev flavor has its
/// own, as it installs next to prod.
const appGroupId = appFlavor == 'dev'
    ? 'group.dev.yannderoues.jolt.dev'
    : 'group.dev.yannderoues.jolt';

/// Home screen widgets (home_widget) only exist on Android and iOS.
bool get supportsHomeWidgets =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Android widgets run Dart through home_widget's background callback; the
/// iOS widget intent starts its own engine on `widgetToggleMain` instead.
bool get usesWidgetBackgroundCallback =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Only iOS has the widget of two plugs: Android has no `JoltPairWidget`.
bool get hasPairWidget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// The Windows runner provides the tray icon and the `jolt/desktop` channel.
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
