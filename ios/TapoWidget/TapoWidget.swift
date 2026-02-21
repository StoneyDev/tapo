import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared Constants & Helpers

private let appGroupId = "group.stoneydev.tapo"
private let devicesKey = "devices"
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

// MARK: - Colors

private let colorOnTint = Color(red: 103.0/255.0, green: 58.0/255.0, blue: 183.0/255.0)
private let colorOffTint = Color(red: 117.0/255.0, green: 117.0/255.0, blue: 117.0/255.0)
private let colorOfflineTint = Color(red: 211.0/255.0, green: 47.0/255.0, blue: 47.0/255.0)

private func iconTintColor(isOnline: Bool, deviceOn: Bool) -> Color {
    if !isOnline { return colorOfflineTint }
    return deviceOn ? colorOnTint : colorOffTint
}

private func iconBackgroundColor(isOnline: Bool, deviceOn: Bool) -> Color {
    if !isOnline { return colorOfflineTint.opacity(0.12) }
    return deviceOn ? colorOnTint.opacity(0.15) : colorOffTint.opacity(0.12)
}

private func iconName(isOnline: Bool, deviceOn: Bool) -> String {
    if !isOnline { return "exclamationmark.triangle.fill" }
    return deviceOn ? "powerplug.fill" : "powerplug"
}

/// Load raw device dictionaries from shared UserDefaults.
func loadDevicesFromStorage() -> [[String: Any]] {
    let userDefaults = UserDefaults(suiteName: appGroupId)
    guard let jsonString = userDefaults?.string(forKey: devicesKey),
          let data = jsonString.data(using: .utf8),
          let devices = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        return []
    }
    return devices
}

// MARK: - Single Plug Widget

struct DeviceEntry: TimelineEntry {
    let date: Date
    let nickname: String
    let model: String
    let ip: String
    let deviceOn: Bool
    let isOnline: Bool
    let hasDevice: Bool
    let isLoading: Bool
}

struct TapoWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = DeviceEntry
    typealias Intent = SelectDeviceIntent

    func placeholder(in context: Context) -> DeviceEntry {
        DeviceEntry(date: Date(), nickname: "Lampe Salon", model: "P110", ip: "", deviceOn: false, isOnline: true, hasDevice: true, isLoading: false)
    }

    func snapshot(for configuration: SelectDeviceIntent, in context: Context) async -> DeviceEntry {
        return getEntry(for: configuration)
    }

    func timeline(for configuration: SelectDeviceIntent, in context: Context) async -> Timeline<DeviceEntry> {
        let entry = getEntry(for: configuration)
        return Timeline(entries: [entry], policy: .never)
    }

    private func getEntry(for configuration: SelectDeviceIntent) -> DeviceEntry {
        let devices = loadDevicesFromStorage()
        guard !devices.isEmpty else {
            return DeviceEntry(date: Date(), nickname: "No device", model: "", ip: "", deviceOn: false, isOnline: true, hasDevice: false, isLoading: false)
        }

        let selectedIp = configuration.device?.id
        let device: [String: Any]
        if let ip = selectedIp, let found = devices.first(where: { ($0["ip"] as? String) == ip }) {
            device = found
        } else if let first = devices.first {
            device = first
        } else {
            return DeviceEntry(date: Date(), nickname: "No device", model: "", ip: "", deviceOn: false, isOnline: true, hasDevice: false, isLoading: false)
        }

        let ip = device["ip"] as? String ?? ""
        let model = device["model"] as? String ?? "Unknown"
        let nickname = device["nickname"] as? String ?? model
        return DeviceEntry(
            date: Date(),
            nickname: nickname,
            model: model,
            ip: ip,
            deviceOn: device["deviceOn"] as? Bool ?? false,
            isOnline: device["isOnline"] as? Bool ?? true,
            hasDevice: true,
            isLoading: isDeviceLoading(ip: ip)
        )
    }
}

struct TapoWidgetEntryView: View {
    var entry: DeviceEntry

    var body: some View {
        if entry.hasDevice && !entry.ip.isEmpty {
            Button(intent: ToggleDeviceIntent(ip: entry.ip)) {
                HStack(spacing: 10) {
                    // Icon in rounded square
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(iconBackgroundColor(isOnline: entry.isOnline, deviceOn: entry.deviceOn))
                            .frame(width: 40, height: 40)

                        if entry.isLoading {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: iconName(isOnline: entry.isOnline, deviceOn: entry.deviceOn))
                                .font(.system(size: 18))
                                .foregroundColor(iconTintColor(isOnline: entry.isOnline, deviceOn: entry.deviceOn))
                        }
                    }

                    // Text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.nickname)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(entry.model)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
            .disabled(entry.isLoading)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "powerplug")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                Text("Add a plug")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    let devices: [(nickname: String, model: String, ip: String, deviceOn: Bool, isOnline: Bool, isLoading: Bool)]
}

struct TapoListWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeviceListEntry {
        DeviceListEntry(date: Date(), devices: [
            (nickname: "Lampe Salon", model: "P110", ip: "192.168.1.1", deviceOn: true, isOnline: true, isLoading: false),
            (nickname: "Bureau", model: "P100", ip: "192.168.1.2", deviceOn: false, isOnline: true, isLoading: false),
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
        let devices = loadDevicesFromStorage()
        guard !devices.isEmpty else {
            return DeviceListEntry(date: Date(), devices: [])
        }

        let parsed = devices.compactMap { device -> (nickname: String, model: String, ip: String, deviceOn: Bool, isOnline: Bool, isLoading: Bool)? in
            guard let ip = device["ip"] as? String,
                  let model = device["model"] as? String else { return nil }
            let nickname = device["nickname"] as? String ?? model
            let deviceOn = device["deviceOn"] as? Bool ?? false
            let isOnline = device["isOnline"] as? Bool ?? true
            return (nickname: nickname, model: model, ip: ip, deviceOn: deviceOn, isOnline: isOnline, isLoading: isDeviceLoading(ip: ip))
        }

        return DeviceListEntry(date: Date(), devices: parsed)
    }
}

struct TapoListWidgetEntryView: View {
    var entry: DeviceListEntry

    var body: some View {
        if entry.devices.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "powerplug")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                Text("No plugs available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tapo Plugs")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 2)

                ForEach(entry.devices, id: \.ip) { device in
                    Button(intent: ToggleDeviceIntent(ip: device.ip)) {
                        HStack(spacing: 8) {
                            // Icon in rounded square
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(iconBackgroundColor(isOnline: device.isOnline, deviceOn: device.deviceOn))
                                    .frame(width: 28, height: 28)

                                if device.isLoading {
                                    ProgressView()
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: iconName(isOnline: device.isOnline, deviceOn: device.deviceOn))
                                        .font(.system(size: 13))
                                        .foregroundColor(iconTintColor(isOnline: device.isOnline, deviceOn: device.deviceOn))
                                }
                            }

                            // Nickname
                            Text(device.nickname)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            // Model
                            Text(device.model)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Spacer()

                            // Status dot
                            Circle()
                                .fill(iconTintColor(isOnline: device.isOnline, deviceOn: device.deviceOn))
                                .frame(width: 8, height: 8)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(device.isLoading)
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
