import WidgetKit
import SwiftUI
import AppIntents

struct DeviceEntry: TimelineEntry {
    let date: Date
    let model: String
    let ip: String
    let deviceOn: Bool
    let hasDevice: Bool
}

struct TapoWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = DeviceEntry
    typealias Intent = SelectDeviceIntent

    func placeholder(in context: Context) -> DeviceEntry {
        DeviceEntry(date: Date(), model: "P110", ip: "", deviceOn: false, hasDevice: true)
    }

    func snapshot(for configuration: SelectDeviceIntent, in context: Context) async -> DeviceEntry {
        return getEntry(for: configuration)
    }

    func timeline(for configuration: SelectDeviceIntent, in context: Context) async -> Timeline<DeviceEntry> {
        let entry = getEntry(for: configuration)
        return Timeline(entries: [entry], policy: .never)
    }

    private func getEntry(for configuration: SelectDeviceIntent) -> DeviceEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.tapo.tapo")
        guard let jsonString = userDefaults?.string(forKey: "devices"),
              let data = jsonString.data(using: .utf8),
              let devices = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !devices.isEmpty else {
            return DeviceEntry(date: Date(), model: "No device", ip: "", deviceOn: false, hasDevice: false)
        }

        // Find selected device by IP from intent
        let selectedIp = configuration.device?.id
        let device: [String: Any]
        if let ip = selectedIp, let found = devices.first(where: { ($0["ip"] as? String) == ip }) {
            device = found
        } else if let first = devices.first {
            device = first
        } else {
            return DeviceEntry(date: Date(), model: "No device", ip: "", deviceOn: false, hasDevice: false)
        }

        let model = device["model"] as? String ?? "Unknown"
        let ip = device["ip"] as? String ?? ""
        let deviceOn = device["deviceOn"] as? Bool ?? false

        return DeviceEntry(date: Date(), model: model, ip: ip, deviceOn: deviceOn, hasDevice: true)
    }
}

struct TapoWidgetEntryView: View {
    var entry: DeviceEntry

    private let deepPurple = Color(red: 103.0/255.0, green: 58.0/255.0, blue: 183.0/255.0)
    private let grey = Color(red: 158.0/255.0, green: 158.0/255.0, blue: 158.0/255.0)

    var body: some View {
        if entry.hasDevice && !entry.ip.isEmpty {
            Link(destination: URL(string: "tapotoggle://toggle?ip=\(entry.ip)")!) {
                HStack {
                    Circle()
                        .fill(entry.deviceOn ? deepPurple : grey)
                        .frame(width: 12, height: 12)
                    Text(entry.model)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
            }
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            Text("Add a plug")
                .font(.caption)
                .foregroundColor(.secondary)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
    }
}

struct TapoWidget: Widget {
    let kind: String = "TapoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectDeviceIntent.self, provider: TapoWidgetProvider()) { entry in
            TapoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tapo Plug")
        .description("Toggle a single Tapo smart plug.")
        .supportedFamilies([.systemSmall])
    }
}
