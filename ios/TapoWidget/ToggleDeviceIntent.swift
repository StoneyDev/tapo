import AppIntents
import Foundation
import WidgetKit
import home_widget

@available(iOS 17, *)
struct ToggleDeviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Device"
    static var description = IntentDescription("Toggles a Tapo smart plug on or off.")

    @Parameter(title: "IP Address")
    var ip: String

    init() {
        self.ip = ""
    }

    init(ip: String) {
        self.ip = ip
    }

    func perform() async throws -> some IntentResult {
        setDeviceLoading(ip: ip, loading: true)
        WidgetCenter.shared.reloadAllTimelines()

        await HomeWidgetBackgroundWorker.run(
            url: URL(string: "tapotoggle://toggle?ip=\(ip)"),
            appGroup: "group.stoneydev.tapo"
        )

        // The Dart callback already clears loading and refreshes widgets.
        // Only reload here as a fallback if Dart failed to clear loading.
        if isDeviceLoading(ip: ip) {
            setDeviceLoading(ip: ip, loading: false)
            WidgetCenter.shared.reloadAllTimelines()
        }

        return .result()
    }
}
