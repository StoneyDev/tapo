# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all tests
flutter test

# Run single test file
flutter test test/path/to/file_test.dart

# Run with coverage
flutter test --coverage

# Build generated code (freezed models)
dart run build_runner build

# Analyze code
flutter analyze
```

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

### Models

`TapoDevice` uses freezed for immutable data class with `copyWith`.
Regenerate with: `dart run build_runner build`

### Testing

Uses `mockito` for mocks. Widget tests use manual mock ViewModels as state containers.
ViewModel tests mock external services (storage, network) but test real logic.
