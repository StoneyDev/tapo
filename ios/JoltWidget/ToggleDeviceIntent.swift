import AppIntents
import Foundation
import WidgetKit

// MARK: - Shared Constants & Helpers

// This file is built into both the app and the widget extension.

let appGroupId = "group.dev.yannderoues.jolt"
private let loadingKeyPrefix = "loading_"

func setDeviceLoading(ip: String, loading: Bool) {
    let userDefaults = UserDefaults(suiteName: appGroupId)
    if loading {
        userDefaults?.set(true, forKey: "\(loadingKeyPrefix)\(ip)")
    } else {
        userDefaults?.removeObject(forKey: "\(loadingKeyPrefix)\(ip)")
    }
}

func isDeviceLoading(ip: String) -> Bool {
    let userDefaults = UserDefaults(suiteName: appGroupId)
    return userDefaults?.bool(forKey: "\(loadingKeyPrefix)\(ip)") ?? false
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
        setDeviceLoading(ip: ip, loading: true)
        WidgetCenter.shared.reloadAllTimelines()

        await WidgetToggle.run(ip: ip)

        // The Dart toggle already clears loading and refreshes widgets.
        // Only reload here as a fallback if Dart failed to clear loading.
        if isDeviceLoading(ip: ip) {
            setDeviceLoading(ip: ip, loading: false)
            WidgetCenter.shared.reloadAllTimelines()
        }

        return .result()
    }
}
#endif
