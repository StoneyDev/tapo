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

// MARK: - Brand

private let brandInkLight = Color(red: 20.0/255.0, green: 26.0/255.0, blue: 24.0/255.0)
private let brandInkDark = Color(red: 244.0/255.0, green: 245.0/255.0, blue: 240.0/255.0)
private let brandLime = Color(red: 199.0/255.0, green: 255.0/255.0, blue: 94.0/255.0)
private let brandIvory = Color(red: 245.0/255.0, green: 242.0/255.0, blue: 233.0/255.0)
private let brandDarkBackground = Color(red: 15.0/255.0, green: 20.0/255.0, blue: 18.0/255.0)
private let brandMutedLight = Color(red: 98.0/255.0, green: 105.0/255.0, blue: 101.0/255.0)
private let brandMutedDark = Color(red: 174.0/255.0, green: 183.0/255.0, blue: 177.0/255.0)
private let brandOffSurfaceLight = Color(red: 240.0/255.0, green: 241.0/255.0, blue: 236.0/255.0)
private let brandOffSurfaceDark = Color(red: 37.0/255.0, green: 44.0/255.0, blue: 40.0/255.0)
private let brandError = Color(red: 212.0/255.0, green: 71.0/255.0, blue: 63.0/255.0)
private let brandErrorDark = Color(red: 255.0/255.0, green: 138.0/255.0, blue: 128.0/255.0)
private let brandErrorSurfaceLight = Color(red: 255.0/255.0, green: 225.0/255.0, blue: 221.0/255.0)
private let brandErrorSurfaceDark = Color(red: 91.0/255.0, green: 31.0/255.0, blue: 28.0/255.0)

private func brandInk(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? brandInkDark : brandInkLight
}

private func brandMuted(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? brandMutedDark : brandMutedLight
}

private func brandOffSurface(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? brandOffSurfaceDark : brandOffSurfaceLight
}

private func brandBackground(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? brandDarkBackground : brandIvory
}

private func iconTintColor(isOnline: Bool, deviceOn: Bool, colorScheme: ColorScheme) -> Color {
    if !isOnline { return colorScheme == .dark ? brandErrorDark : brandError }
    return deviceOn ? brandInkLight : brandMuted(colorScheme)
}

private func iconBackgroundColor(isOnline: Bool, deviceOn: Bool, colorScheme: ColorScheme) -> Color {
    if !isOnline {
        return colorScheme == .dark ? brandErrorSurfaceDark : brandErrorSurfaceLight
    }
    return deviceOn ? brandLime : brandOffSurface(colorScheme)
}

private func iconName(isOnline: Bool, deviceOn: Bool) -> String {
    if !isOnline { return "exclamationmark.triangle.fill" }
    return deviceOn ? "powerplug.fill" : "powerplug"
}

private func brandMark(size: CGFloat) -> some View {
    Image(systemName: "power")
        .font(.system(size: size * 0.48, weight: .heavy))
        .foregroundColor(brandInkLight)
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: size * 0.3).fill(brandLime))
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
        } else {
            device = devices[0]
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if entry.hasDevice && !entry.ip.isEmpty {
            Button(intent: ToggleDeviceIntent(ip: entry.ip)) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        brandMark(size: 22)
                        Text("TAPO HOME")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                            .foregroundColor(brandMuted(colorScheme))
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(iconBackgroundColor(isOnline: entry.isOnline, deviceOn: entry.deviceOn, colorScheme: colorScheme))
                            .frame(width: 52, height: 52)

                        if entry.isLoading {
                            ProgressView()
                                .tint(iconTintColor(isOnline: entry.isOnline, deviceOn: entry.deviceOn, colorScheme: colorScheme))
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: iconName(isOnline: entry.isOnline, deviceOn: entry.deviceOn))
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(iconTintColor(isOnline: entry.isOnline, deviceOn: entry.deviceOn, colorScheme: colorScheme))
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.nickname)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(brandInk(colorScheme))
                            .lineLimit(1)

                        Text(entry.model)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(brandMuted(colorScheme))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(entry.isLoading)
            .containerBackground(for: .widget) {
                brandBackground(colorScheme)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    brandMark(size: 22)
                    Text("TAPO HOME")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(brandMuted(colorScheme))
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(brandMuted(colorScheme))
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 15).fill(brandOffSurface(colorScheme)))
                Text("Add a plug")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(brandInk(colorScheme))
                Text("Open Tapo to get started")
                    .font(.system(size: 11))
                    .foregroundColor(brandMuted(colorScheme))
                    .lineLimit(1)
            }
            .containerBackground(for: .widget) {
                brandBackground(colorScheme)
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
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var widgetFamily

    private var visibleDevices: ArraySlice<(nickname: String, model: String, ip: String, deviceOn: Bool, isOnline: Bool, isLoading: Bool)> {
        entry.devices.prefix(widgetFamily == .systemLarge ? 7 : 3)
    }

    var body: some View {
        if entry.devices.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "powerplug")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(brandInkLight)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 15).fill(brandLime))
                Text("No plugs available")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(brandInk(colorScheme))
                Text("Open Tapo to add a device")
                    .font(.system(size: 11))
                    .foregroundColor(brandMuted(colorScheme))
            }
            .containerBackground(for: .widget) {
                brandBackground(colorScheme)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 7) {
                        brandMark(size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TAPO HOME")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(1.2)
                                .foregroundColor(brandMuted(colorScheme))
                            Text("Prises")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(brandInk(colorScheme))
                        }
                    }

                    Spacer()

                    Text("\(entry.devices.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(brandMuted(colorScheme))
                        .frame(width: 28, height: 24)
                        .background(Capsule().fill(brandOffSurface(colorScheme)))
                }

                ForEach(visibleDevices, id: \.ip) { device in
                    Button(intent: ToggleDeviceIntent(ip: device.ip)) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(iconBackgroundColor(isOnline: device.isOnline, deviceOn: device.deviceOn, colorScheme: colorScheme))
                                    .frame(width: 32, height: 32)

                                if device.isLoading {
                                    ProgressView()
                                        .tint(iconTintColor(isOnline: device.isOnline, deviceOn: device.deviceOn, colorScheme: colorScheme))
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: iconName(isOnline: device.isOnline, deviceOn: device.deviceOn))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(iconTintColor(isOnline: device.isOnline, deviceOn: device.deviceOn, colorScheme: colorScheme))
                                }
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(device.nickname)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(brandInk(colorScheme))
                                    .lineLimit(1)
                                Text(device.model)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(brandMuted(colorScheme))
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(device.isLoading)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .containerBackground(for: .widget) {
                brandBackground(colorScheme)
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
