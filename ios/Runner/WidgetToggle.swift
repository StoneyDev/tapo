import Flutter
import UIKit
import WidgetKit

/// Runs the Dart toggle of a widget plug on a headless engine. The app's own
/// engine needs a scene, which iOS does not create when it launches the app
/// in the background to perform a widget intent.
@MainActor
enum WidgetToggle {
  /// How long a toggle may take, past the Dart toggle's own 10 s timeout.
  private static let timeout: TimeInterval = 20

  /// Toggles run one after the other, as on Android: they rewrite the same
  /// widget device list.
  private static var last: Task<Void, Never>?
  /// When the last pending toggle gives up.
  private static var lastDeadline = Date.distantPast

  /// Shows the plug at `ip` loading in the widgets and toggles it in the
  /// background.
  static func start(ip: String) {
    // A toggle waits for the pending ones, so it gives up after them.
    let deadline = max(Date(), lastDeadline) + timeout
    lastDeadline = deadline
    setDeviceLoading(ip: ip, until: deadline)
    WidgetCenter.shared.reloadAllTimelines()

    let previous = last
    let background = BackgroundTime()
    last = Task {
      await previous?.value
      await toggle(ip: ip, until: deadline)
      // The Dart toggle already clears loading and refreshes widgets.
      // Only reload here as a fallback if Dart failed to clear loading.
      if deviceLoadingDeadline(ip: ip) == deadline {
        setDeviceLoading(ip: ip, until: nil)
        WidgetCenter.shared.reloadAllTimelines()
      }
      if lastDeadline == deadline {
        lastDeadline = .distantPast
      }
      background.end()
    }
  }

  /// Toggles the plug at `ip`, giving up at `deadline`, when the widgets stop
  /// showing it loading. Past it, as when iOS suspended the app meanwhile, the
  /// toggle no longer runs.
  private static func toggle(ip: String, until deadline: Date) async {
    guard deadline > Date() else { return }
    let engine = FlutterEngine(
      name: "widget_toggle", project: nil, allowHeadlessExecution: true)

    await withCheckedContinuation { continuation in
      let wait = ToggleWait(continuation)
      guard
        engine.run(
          withEntrypoint: "widgetToggleMain",
          libraryURI: "package:jolt/services/widget_callback.dart",
          initialRoute: nil,
          entrypointArgs: [ip])
      else {
        return wait.resume()
      }
      // Dart reaches the channel through this main thread, so it cannot send
      // done before the handler is set.
      FlutterMethodChannel(name: "jolt/widget_toggle", binaryMessenger: engine.binaryMessenger)
        .setMethodCallHandler { call, result in
          guard call.method == "done" else {
            return result(FlutterMethodNotImplemented)
          }
          result(nil)
          wait.resume()
        }
      GeneratedPluginRegistrant.register(with: engine)
      // Give up so that the next toggle can run.
      DispatchQueue.main.asyncAfter(deadline: .now() + deadline.timeIntervalSinceNow) {
        wait.resume()
      }
    }

    engine.destroyContext()
  }
}

/// Keeps the app running until `end`, as iOS suspends it once the intent
/// returned.
@MainActor
private final class BackgroundTime {
  private var task = UIBackgroundTaskIdentifier.invalid

  init() {
    task = UIApplication.shared.beginBackgroundTask(withName: "widget_toggle") { self.end() }
  }

  func end() {
    guard task != .invalid else { return }
    UIApplication.shared.endBackgroundTask(task)
    task = .invalid
  }
}

/// Resumes the wait for a toggle once, on done or on the timeout. Only used on
/// the main thread.
private final class ToggleWait: @unchecked Sendable {
  private var continuation: CheckedContinuation<Void, Never>?

  init(_ continuation: CheckedContinuation<Void, Never>) {
    self.continuation = continuation
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}
