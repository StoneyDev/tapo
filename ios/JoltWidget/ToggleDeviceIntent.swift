import AppIntents
import Foundation
import WidgetKit

// MARK: - Shared Constants & Helpers

// This file is built into both the app and the widget extension.

let appGroupId = "group.dev.yannderoues.jolt"
private let loadingKeyPrefix = "loading_"

/// Shows the plug at `ip` loading until `deadline`, or no longer if nil. The
/// deadline keeps a toggle that never ends from showing it loading for good.
///
/// It is stored as a number: Dart reads `loading_<ip>` through home_widget
/// when clearing it, and Flutter's codec aborts the app on a `Date`.
func setDeviceLoading(ip: String, until deadline: Date?) {
    let userDefaults = UserDefaults(suiteName: appGroupId)
    if let deadline {
        userDefaults?.set(
            deadline.timeIntervalSinceReferenceDate, forKey: "\(loadingKeyPrefix)\(ip)")
    } else {
        userDefaults?.removeObject(forKey: "\(loadingKeyPrefix)\(ip)")
    }
}

/// Until when the plug at `ip` shows loading, if it was set to.
func deviceLoadingDeadline(ip: String) -> Date? {
    let userDefaults = UserDefaults(suiteName: appGroupId)
    guard
        let seconds = userDefaults?.object(forKey: "\(loadingKeyPrefix)\(ip)") as? TimeInterval
    else { return nil }
    return Date(timeIntervalSinceReferenceDate: seconds)
}

// MARK: - Toggle Intent

@available(iOS 17, *)
struct ToggleDeviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Device"
    static var description = IntentDescription("Toggles a Tapo smart plug on or off.")

    /// Only the app can run Dart. Before iOS 27, the app-only conformance
    /// below makes the system perform the intent there.
    @available(iOS 27, *)
    static var allowedExecutionTargets: ExecutionTargets { .main }

    /// The credentials live in the keychain, which locks with the device.
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    /// A widget button, not an action for Shortcuts or Spotlight.
    static var isDiscoverable: Bool { false }

    @Parameter(title: "IP Address")
    var ip: String

    init() {
        self.ip = ""
    }

    init(ip: String) {
        self.ip = ip
    }
}

#if WIDGET_EXTENSION
@available(iOS 17, *)
extension ToggleDeviceIntent {
    // Never called: the system performs the intent in the app, see below.
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
#else
/// Conforming in the app alone makes the system perform the intent there,
/// where it can run Dart, rather than in the widget extension.
@available(iOS 17, *)
extension ToggleDeviceIntent: ForegroundContinuableIntent {
    func perform() async throws -> some IntentResult {
        // The tapped widget only reloads once perform returns: return before
        // the toggle so that it shows the plug loading meanwhile.
        await WidgetToggle.start(ip: ip)
        return .result()
    }
}
#endif
