# Tapo

Flutter app for controlling TP-Link Tapo smart plugs over local network.

## Features

- Local control of Tapo smart plugs (no cloud dependency)
- Dual protocol support: KLAP (port 80) and TPAP/TLS (port 4433)
- Auto protocol detection with KLAP-first fallback
- Interactive single-plug and multi-plug home screen widgets on Android and iOS
- Windows 10/11 desktop app living in the notification area: right-click the
  tray icon to switch plugs without opening the window (like Steam or Discord)

## Architecture

```
lib/
├── core/           # Protocol implementations (KLAP, TPAP, SPAKE2+)
├── services/       # Device communication & business logic
├── providers/      # State management (Riverpod notifiers)
├── views/          # UI screens & widgets
└── models/         # Data models (freezed)
```

State and dependency injection via `flutter_riverpod`: the signed-in account
drives the screens and the plug sessions.

## Development

Use Flutter 3.47.6 (configured in `.puro.json` and `.fvmrc`). Android uses
Gradle 9.8.0, AGP 9.4.1 and built-in Kotlin, with a Java 21 Gradle daemon.
iOS requires iOS 15 or later (iOS 17 for widgets) and uses Swift Package Manager
for both the app and widget extension; CocoaPods is no longer required.

Common tasks are in the `Makefile` (`make` lists them):

```bash
make test               # run tests (make coverage for coverage)
make gen                # regenerate freezed models
make analyze            # lint
make build-android      # Android release APK (signed, see Releases)
make build-windows      # Windows release build (on Windows only)
make package-windows    # portable zip: build/tapo-windows-x64.zip
puro flutter build ios --no-codesign    # iOS release build without signing
```

## Windows

Flutter builds Windows apps on Windows only. Requirements on the PC:

- Windows 10 or 11, [puro](https://puro.dev) with the Flutter version above
- Visual Studio 2022 or 2026 with the "Desktop development with C++"
  workload
- GNU make: `winget install ezwinports.make` (works from cmd, PowerShell or
  Git Bash)

Then `make package-windows` produces a portable zip: unzip it anywhere and run
`tapo.exe`. Tagged releases ship the same zip (see Releases).

Behaviour:

- **Tray icon**: left click opens the window; right click lists the plugs
  (✓ = on), "Tout éteindre", "Ouvrir Tapo", "Lancer au démarrage" and
  "Quitter". Plug states are refreshed when the menu opens.
- **Close button** hides the window to the tray; "Quitter" exits.
- **Lancer au démarrage** (tray menu or sidebar) adds a per-user
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` entry that starts
  Tapo hidden in the tray (`--minimized`). It also shows in Task Manager's
  Startup apps.
- Launching Tapo again brings the running window forward (single instance).
- On Windows 11 new tray icons go to the overflow menu (^): drag Tapo to the
  taskbar, or enable it in Settings > Personalization > Taskbar > Other system
  tray icons.

The native side lives in `windows/runner/` (`tray_icon.cpp`,
`launch_at_startup.cpp`, `flutter_window.cpp`) and talks to Dart through the
`tapo/desktop` method channel (`lib/services/desktop_shell.dart`).

## Releases

Pushing a `v*` tag runs `.github/workflows/release.yml`: analyze and tests,
then a GitHub Release with `tapo-<version>-windows-x64.zip` and
`tapo-<version>-android.apk`. The tag must match the pubspec version; a
suffixed tag (`v1.2.0-beta.1`) becomes a prerelease.

```bash
# bump `version:` in pubspec.yaml (e.g. 1.2.0+4), commit, then:
git tag v1.2.0 && git push origin v1.2.0
```

Android releases are signed with an upload key so that every APK updates the
previous one. Locally, `android/key.properties` (never committed) points to the
keystore; without it, release builds fall back to debug keys:

```properties
storeFile=/absolute/path/to/tapo-release.jks
storePassword=...
keyPassword=...
keyAlias=tapo
```

CI reads the same key from two repository secrets (Settings > Secrets and
variables > Actions): `ANDROID_KEYSTORE_BASE64` (`base64 -i tapo-release.jks`)
and `ANDROID_KEYSTORE_PASSWORD`. Back up the keystore and its password: a lost
key means users must uninstall the app to get updates.

The Windows build is not code-signed: on first launch of a downloaded zip,
SmartScreen asks to confirm ("More info" > "Run anyway").
