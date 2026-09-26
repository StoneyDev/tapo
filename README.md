# Tapo

Flutter app for controlling TP-Link Tapo smart plugs over local network.

## Features

- Local control of Tapo smart plugs (no cloud dependency)
- Dual protocol support: KLAP (port 80) and TPAP/TLS (port 4433)
- Auto protocol detection with KLAP-first fallback
- Interactive single-plug and multi-plug home screen widgets on Android and iOS

## Architecture

```
lib/
├── core/           # Protocol implementations (KLAP, TPAP, SPAKE2+)
├── services/       # Device communication & business logic
├── viewmodels/     # State management (ChangeNotifier)
├── views/          # UI screens & widgets
└── models/         # Data models (freezed)
```

DI via `get_it`. Reactive UI via `watch_it`.

## Development

Use Flutter 3.47.3 (configured in `.puro.json` and `.fvmrc`). Android uses
Gradle 9.8.0, AGP 9.4.1 and built-in Kotlin, with a Java 21 Gradle daemon.
iOS requires iOS 15 or later (iOS 17 for widgets) and uses Swift Package Manager
for both the app and widget extension; CocoaPods is no longer required.

```bash
puro flutter test                       # run tests
puro flutter test --coverage            # run with coverage
puro dart run build_runner build        # regenerate freezed models
puro flutter analyze                    # lint
puro flutter build apk                  # Android release build
puro flutter build ios --no-codesign    # iOS release build without signing
```
