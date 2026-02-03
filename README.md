# Tapo

Flutter app for controlling TP-Link Tapo smart plugs over local network.

## Features

- Local control of Tapo smart plugs (no cloud dependency)
- Dual protocol support: KLAP (port 80) and TPAP/TLS (port 4433)
- Auto protocol detection with KLAP-first fallback
- Home screen widgets via `home_widget`

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

```bash
flutter test                          # run tests
flutter test --coverage               # run with coverage
dart run build_runner build           # regenerate freezed models
flutter analyze                       # lint
```
