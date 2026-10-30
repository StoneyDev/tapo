# Jolt - common tasks.
# GNU make on macOS, Linux and Windows (cmd or Git Bash).
# Windows: install GNU make once with `winget install ezwinports.make`.

FLUTTER ?= puro flutter
DART ?= puro dart

WINDOWS_RELEASE := build/windows/x64/runner/Release
WINDOWS_ZIP := build/jolt-windows-x64.zip

.DEFAULT_GOAL := help
.PHONY: help deps gen analyze test coverage build-android build-windows \
	package-windows clean

# $(info) is printed by make itself: same output under cmd and sh.
help:
	$(info Jolt - available commands:)
	$(info make deps             Install dependencies)
	$(info make gen              Regenerate freezed models)
	$(info make analyze          Static analysis)
	$(info make test             Run all tests)
	$(info make coverage         Run tests with coverage)
	$(info make build-android    Release APK in build/app/outputs/flutter-apk)
	$(info make build-windows    Release app in $(WINDOWS_RELEASE) - on Windows)
	$(info make package-windows  Portable zip $(WINDOWS_ZIP) - on Windows)
	$(info make clean            Delete build outputs)
	@cd .

deps:
	$(FLUTTER) pub get

gen:
	$(DART) run build_runner build --delete-conflicting-outputs

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

coverage:
	$(FLUTTER) test --coverage

build-android:
	$(FLUTTER) build apk --release

# Flutter only builds Windows apps on Windows (Visual Studio 2022 with the
# "Desktop development with C++" workload).
build-windows:
	$(FLUTTER) build windows --release

package-windows: build-windows
	powershell -NoProfile -Command "Compress-Archive -Path '$(WINDOWS_RELEASE)/*' -DestinationPath '$(WINDOWS_ZIP)' -Force"

clean:
	$(FLUTTER) clean
