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

```bash
puro flutter test                       # run tests
puro flutter test --coverage            # run with coverage
puro dart run build_runner build        # regenerate freezed models
puro flutter analyze                    # lint
```
