import Flutter

/// Runs the Dart toggle of a widget plug on a headless engine. The app's own
/// engine needs a scene, which iOS does not create when it launches the app
/// in the background to perform a widget intent.
@MainActor
enum WidgetToggle {
  /// Toggles run one after the other, as on Android: they rewrite the same
  /// widget device list.
  private static var last: Task<Void, Never>?

  static func run(ip: String) async {
    let previous = last
    let task = Task {
      await previous?.value
      await toggle(ip: ip)
    }
    last = task
    await task.value
  }

  private static func toggle(ip: String) async {
    let engine = FlutterEngine(
      name: "widget_toggle", project: nil, allowHeadlessExecution: true)

    await withCheckedContinuation { continuation in
      let wait = ToggleWait(continuation)
      guard
        engine.run(
          withEntrypoint: "widgetToggleMain",
          libraryURI: "package:tapo/services/widget_callback.dart",
          initialRoute: nil,
          entrypointArgs: [ip])
      else {
        return wait.resume()
      }
      // Dart reaches the channel through this main thread, so it cannot send
      // done before the handler is set.
      FlutterMethodChannel(name: "tapo/widget_toggle", binaryMessenger: engine.binaryMessenger)
        .setMethodCallHandler { call, result in
          guard call.method == "done" else {
            return result(FlutterMethodNotImplemented)
          }
          result(nil)
          wait.resume()
        }
      GeneratedPluginRegistrant.register(with: engine)
      // Past the Dart toggle's own 10 s timeout, give up so the intent can
      // clear the loading state.
      DispatchQueue.main.asyncAfter(deadline: .now() + 20) { wait.resume() }
    }

    engine.destroyContext()
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
