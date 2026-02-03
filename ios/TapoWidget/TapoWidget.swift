import WidgetKit
import SwiftUI
import AppIntents

struct DeviceEntry: TimelineEntry {
    let date: Date
    let model: String
    let ip: String
    let deviceOn: Bool
    let isOnline: Bool
    let hasDevice: Bool
}

struct TapoWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = DeviceEntry
    typealias Intent = SelectDeviceIntent

    func placeholder(in context: Context) -> DeviceEntry {
        DeviceEntry(date: Date(), model: "P110", ip: "", deviceOn: false, isOnline: true, hasDevice: true)
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
            return DeviceEntry(date: Date(), model: "No device", ip: "", deviceOn: false, isOnline: true, hasDevice: false)
        }

        // Find selected device by IP from intent
        let selectedIp = configuration.device?.id
        let device: [String: Any]
        if let ip = selectedIp, let found = devices.first(where: { ($0["ip"] as? String) == ip }) {
            device = found
        } else if let first = devices.first {
            device = first
        } else {
            return DeviceEntry(date: Date(), model: "No device", ip: "", deviceOn: false, isOnline: true, hasDevice: false)
        }

        let model = device["model"] as? String ?? "Unknown"
        let ip = device["ip"] as? String ?? ""
        let deviceOn = device["deviceOn"] as? Bool ?? false
        let isOnline = device["isOnline"] as? Bool ?? true

        return DeviceEntry(date: Date(), model: model, ip: ip, deviceOn: deviceOn, isOnline: isOnline, hasDevice: true)
    }
}

struct TapoWidgetEntryView: View {
    var entry: DeviceEntry

    private let deepPurple = Color(red: 103.0/255.0, green: 58.0/255.0, blue: 183.0/255.0)
    private let grey = Color(red: 158.0/255.0, green: 158.0/255.0, blue: 158.0/255.0)
    private let offline = Color(red: 211.0/255.0, green: 47.0/255.0, blue: 47.0/255.0)

    var body: some View {
        if entry.hasDevice && !entry.ip.isEmpty {
            Link(destination: URL(string: "tapotoggle://toggle?ip=\(entry.ip)")!) {
                HStack {
                    Circle()
                        .fill(!entry.isOnline ? offline : entry.deviceOn ? deepPurple : grey)
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

// MARK: - List Widget (All Plugs)

struct DeviceListEntry: TimelineEntry {
    let date: Date
    let devices: [(model: String, ip: String, deviceOn: Bool, isOnline: Bool)]
}

struct TapoListWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeviceListEntry {
        DeviceListEntry(date: Date(), devices: [
            (model: "P110", ip: "192.168.1.1", deviceOn: true, isOnline: true),
            (model: "P100", ip: "192.168.1.2", deviceOn: false, isOnline: true),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (DeviceListEntry) -> Void) {
        completion(getEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeviceListEntry>) -> Void) {
        let entry = getEntry()
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func getEntry() -> DeviceListEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.tapo.tapo")
        guard let jsonString = userDefaults?.string(forKey: "devices"),
              let data = jsonString.data(using: .utf8),
              let devices = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !devices.isEmpty else {
            return DeviceListEntry(date: Date(), devices: [])
        }

        let parsed = devices.compactMap { device -> (model: String, ip: String, deviceOn: Bool, isOnline: Bool)? in
            guard let ip = device["ip"] as? String,
                  let model = device["model"] as? String else { return nil }
            let deviceOn = device["deviceOn"] as? Bool ?? false
            let isOnline = device["isOnline"] as? Bool ?? true
            return (model: model, ip: ip, deviceOn: deviceOn, isOnline: isOnline)
        }

        return DeviceListEntry(date: Date(), devices: parsed)
    }
}

struct TapoListWidgetEntryView: View {
    var entry: DeviceListEntry

    private let deepPurple = Color(red: 103.0/255.0, green: 58.0/255.0, blue: 183.0/255.0)
    private let grey = Color(red: 158.0/255.0, green: 158.0/255.0, blue: 158.0/255.0)
    private let offline = Color(red: 211.0/255.0, green: 47.0/255.0, blue: 47.0/255.0)

    var body: some View {
        if entry.devices.isEmpty {
            Text("No plugs available")
                .font(.caption)
                .foregroundColor(.secondary)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tapo Plugs")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
                ForEach(entry.devices, id: \.ip) { device in
                    Link(destination: URL(string: "tapotoggle://toggle?ip=\(device.ip)")!) {
                        HStack {
                            Circle()
                                .fill(!device.isOnline ? offline : device.deviceOn ? deepPurple : grey)
                                .frame(width: 10, height: 10)
                            Text(device.model)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        }
    }
}

struct TapoListWidget: Widget {
    let kind: String = "TapoListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TapoListWidgetProvider()) { entry in
            TapoListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tapo Plugs")
        .description("View and toggle all Tapo smart plugs.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
