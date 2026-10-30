# AGENTS.md

Guidance for coding agents working in this repository.

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

# Build generated code (freezed models and states, mockito mocks)
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

Flutter app (named Jolt) for controlling TP-Link Tapo smart plugs over local
network. Only user-facing strings say Jolt: code identifiers (Dart package, app
id, channels, registry value) keep `tapo`.

### Layers

```
lib/
├── core/           # Protocol implementations
├── services/       # Business logic & device communication
├── providers/      # Riverpod providers and notifiers (state management)
├── views/          # UI screens & widgets
└── models/         # Data models (freezed)
```

### Protocol Stack

TapoService handles two authentication protocols:
- **KLAP** (older firmware): 2-stage handshake at port 80, AES-CBC encrypted requests
- **TPAP** (firmware 1.4+): TLS on port 4433, SPAKE2+ auth

TapoService tries KLAP first, falls back to TPAP. Sessions cached per device IP.

### State Management and Dependency Injection

`flutter_riverpod` 3, without code generation. `main()` creates a
`ProviderContainer`, starts the tray with it on Windows and runs the app in an
`UncontrolledProviderScope`.

- `providers/services.dart`: one provider per service (secure storage, widget
  data, desktop shell). `tapoServiceProvider` derives the `TapoService` from
  the signed-in account (null when signed out); disposing it closes the plug
  sessions.
- `authProvider` (`AsyncNotifier`): the stored account, source of truth for
  the session. The app root shows `HomeScreen` when signed in and
  `ConfigScreen` otherwise: there is no imperative navigation.
- `homeProvider` (`Notifier<HomeState>`): plugs, loading, errors, toggles and
  power-off countdowns, shared by the window and the tray. It rebuilds on
  account change and loads the plugs itself. Async work checks that the
  account did not change meanwhile before publishing. `plugListProvider` and
  `plugProvider(ip)` project it so a countdown tick only rebuilds its card.
- `configProvider` (auto-dispose `AsyncNotifier`): the configuration form;
  saving signs in. `launchAtStartupProvider`: the Windows startup setting.

States are immutable freezed classes next to their notifier. Widgets are
`ConsumerWidget`s: `ref.watch` (with `select` or a projection provider) for
state, `ref.read(provider.notifier)` in callbacks. `PlugBuilder` wires a
`PlugCard` or `PlugTile` to its plug. A notifier cannot change state during
its `build` or a widget's life-cycle methods.

### Windows desktop

`windows/runner/` hosts a tray icon (`tray_icon.cpp`), launch at startup
(`launch_at_startup.cpp`) and the `tapo/desktop` method channel
(`flutter_window.cpp`). Dart side: `DesktopShell` (channel wrapper),
`TrayController` (reads providers through a `Ref`, builds the tray menu from
`homeProvider`, refreshing plug states within a 450 ms budget),
`launchAtStartupProvider`. Closing the window
hides it to the tray. Platform checks live in `lib/core/platform.dart`;
`WidgetDataService` is a no-op without home screen widgets.

The runner compiles with `/W4 /WX`: keep C++ warning-free. It cannot be built
on macOS; Windows builds need a Windows host.

Layout switches to the desktop layout (`lib/views/desktop/`) at >= 720 px
width; mobile layout stays unchanged below.

### iOS widgets

The app uses the UIScene life cycle (required by the iOS 27 SDK).
`ToggleDeviceIntent` is built into both the app and the widget extension
(which defines `WIDGET_EXTENSION`) and is performed in the app: `WidgetToggle`
runs `widgetToggleMain` on a headless engine, because iOS creates no scene,
hence no app engine, when it launches the app in the background for an
intent. Android widgets go through home_widget's background callback instead.

### Models

`TapoDevice` and the provider states use freezed for immutable data classes
with `copyWith`. Regenerate with `puro dart run build_runner build`.

### Testing

Uses `mockito` for mocks. Provider tests use `ProviderContainer.test` with the
services overridden (`test/helpers/providers.dart`) and test the real
notifiers. Widget tests wrap screens in a `ProviderScope`: `FakeHomeNotifier`
(`test/views/home_test_doubles.dart`) sets the home state, other screens use
the real notifiers on mocked services. Goldens live in `test/views/goldens/`.
