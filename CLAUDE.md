# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Flutter Version

This project uses **puro** for Flutter version management. The required version is defined in `.puro.json`.
Always use `puro flutter` and `puro dart` instead of `flutter` and `dart` directly.

## Commands

```bash
# Run all tests
puro flutter test

# Run single test file
puro flutter test test/path/to/file_test.dart

# Run with coverage
puro flutter test --coverage

# Build generated code (freezed models)
puro dart run build_runner build --delete-conflicting-outputs

# Analyze code
puro flutter analyze

# Platform builds (see `make` for the full list)
make build-android
make build-windows      # Windows host only
```

Pushing a `v*` tag matching the pubspec version publishes a GitHub Release
(Windows zip + signed APK) via `.github/workflows/release.yml`.

## Architecture

Flutter app for controlling TP-Link Tapo smart plugs over local network.

### Layers

```
lib/
├── core/           # Protocol implementations
├── services/       # Business logic & device communication
├── viewmodels/     # State management (ChangeNotifier)
├── views/          # UI screens & widgets
└── models/         # Data models (freezed)
```

### Protocol Stack

TapoService handles two authentication protocols:
- **KLAP** (older firmware): 2-stage handshake at port 80, AES-CBC encrypted requests
- **TPAP** (firmware 1.4+): TLS on port 4433, SPAKE2+ auth

TapoService tries KLAP first, falls back to TPAP. Sessions cached per device IP.

### Dependency Injection

`get_it` for DI. `setupLocator()` in `lib/core/di.dart` registers singletons.
`registerTapoService()` called after auth to register TapoService with credentials.

### State Management

ViewModels extend `ChangeNotifier`. Views use `watch_it` package (`watchIt()`) for reactive updates.

### Windows desktop

`windows/runner/` hosts a tray icon (`tray_icon.cpp`), launch at startup
(`launch_at_startup.cpp`) and the `tapo/desktop` method channel
(`flutter_window.cpp`). Dart side: `DesktopShell` (channel wrapper),
`TrayController` (builds the tray menu from `HomeViewModel`, refreshing plug
states within a 450 ms budget), `LaunchAtStartupViewModel`. Closing the window
hides it to the tray. Platform checks live in `lib/core/platform.dart`;
`WidgetDataService` is a no-op without home screen widgets.

The runner compiles with `/W4 /WX`: keep C++ warning-free. It cannot be built
on macOS; Windows builds need a Windows host.

Layout switches to the desktop layout (`lib/views/desktop/`) at >= 720 px
width; mobile layout stays unchanged below.

### Models

`TapoDevice` uses freezed for immutable data class with `copyWith`.
Regenerate with: `dart run build_runner build`

### Testing

Uses `mockito` for mocks. Widget tests use manual mock ViewModels as state containers.
ViewModel tests mock external services (storage, network) but test real logic.
