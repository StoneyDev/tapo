import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared Constants & Helpers

private let devicesKey = "devices"

/// Whether a plug loading until `deadline` shows loading at `date`.
private func showsLoading(until deadline: Date?, at date: Date) -> Bool {
    (deadline ?? .distantPast) > date
}

// MARK: - Brand

private let brandInkLight = Color(red: 16/255, green: 16/255, blue: 16/255)
private let brandInkDark = Color(red: 247/255, green: 247/255, blue: 247/255)
private let brandPearl = Color(red: 243/255, green: 243/255, blue: 241/255)
private let brandMutedLight = Color(red: 109/255, green: 109/255, blue: 109/255)
private let brandMutedDark = Color(red: 153/255, green: 153/255, blue: 153/255)
private let brandOffSurfaceLight = Color(red: 234/255, green: 234/255, blue: 234/255)
private let brandOffSurfaceDark = Color(red: 36/255, green: 36/255, blue: 36/255)
private let brandError = Color(red: 216/255, green: 45/255, blue: 64/255)
private let brandErrorDark = Color(red: 255/255, green: 81/255, blue: 93/255)
private let brandErrorSurfaceLight = Color(red: 255/255, green: 232/255, blue: 235/255)
private let brandErrorSurfaceDark = Color(red: 50/255, green: 20/255, blue: 23/255)

private func brandAccent(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
        ? Color(red: 77/255, green: 91/255, blue: 255/255)
        : Color(red: 57/255, green: 72/255, blue: 255/255)
}

private func deviceStatus(isOnline: Bool, deviceOn: Bool) -> String {
    if !isOnline { return "Hors ligne" }
    return deviceOn ? "Allumée" : "Éteinte"
}

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
    colorScheme == .dark ? .black : brandPearl
}

private func iconTintColor(isOnline: Bool, deviceOn: Bool, colorScheme: ColorScheme) -> Color {
    if !isOnline { return colorScheme == .dark ? brandErrorDark : brandError }
    return deviceOn ? .white : brandMuted(colorScheme)
}

private func iconBackgroundColor(isOnline: Bool, deviceOn: Bool, colorScheme: ColorScheme) -> Color {
    if !isOnline {
        return colorScheme == .dark ? brandErrorSurfaceDark : brandErrorSurfaceLight
    }
    return deviceOn ? brandAccent(colorScheme) : brandOffSurface(colorScheme)
}

private func iconName(isOnline: Bool) -> String {
    if !isOnline { return "exclamationmark.triangle.fill" }
    return "power"
}

private func powerControl(isOnline: Bool, deviceOn: Bool, isLoading: Bool, size: CGFloat, glyph: CGFloat, colorScheme: ColorScheme) -> some View {
    let tint = iconTintColor(isOnline: isOnline, deviceOn: deviceOn, colorScheme: colorScheme)
    return ZStack {
        Circle()
            .fill(iconBackgroundColor(isOnline: isOnline, deviceOn: deviceOn, colorScheme: colorScheme))
            .frame(width: size, height: size)

        if isLoading {
            ProgressView()
                .tint(tint)
                .frame(width: glyph, height: glyph)
        } else {
            Image(systemName: iconName(isOnline: isOnline))
                .font(.system(size: glyph, weight: .semibold))
                .foregroundColor(tint)
        }
    }
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
    var date: Date
    let nickname: String
    let model: String
    let ip: String
    let deviceOn: Bool
    let isOnline: Bool
    let hasDevice: Bool
    let loadingUntil: Date?

    var isLoading: Bool { showsLoading(until: loadingUntil, at: date) }
}

struct JoltWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = DeviceEntry
    typealias Intent = SelectDeviceIntent

    func placeholder(in context: Context) -> DeviceEntry {
        DeviceEntry(date: Date(), nickname: "Lampe Salon", model: "P110", ip: "", deviceOn: false, isOnline: true, hasDevice: true, loadingUntil: nil)
    }

    func snapshot(for configuration: SelectDeviceIntent, in context: Context) async -> DeviceEntry {
        return getEntry(for: configuration)
    }

    func timeline(for configuration: SelectDeviceIntent, in context: Context) async -> Timeline<DeviceEntry> {
        let entry = getEntry(for: configuration)
        var entries = [entry]
        // Stop loading at the deadline, should the app not reload the widget
        // once the toggle ended.
        if entry.isLoading, let deadline = entry.loadingUntil {
            var settled = entry
            settled.date = deadline
            entries.append(settled)
        }
        return Timeline(entries: entries, policy: .never)
    }

    private func getEntry(for configuration: SelectDeviceIntent) -> DeviceEntry {
        let devices = loadDevicesFromStorage()
        guard !devices.isEmpty else {
            return DeviceEntry(date: Date(), nickname: "No device", model: "", ip: "", deviceOn: false, isOnline: true, hasDevice: false, loadingUntil: nil)
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
            loadingUntil: deviceLoadingDeadline(ip: ip)
        )
    }
}

struct JoltWidgetEntryView: View {
    var entry: DeviceEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if entry.hasDevice && !entry.ip.isEmpty {
            Button(intent: ToggleDeviceIntent(ip: entry.ip)) {
                VStack(alignment: .leading, spacing: 0) {
                    powerControl(isOnline: entry.isOnline, deviceOn: entry.deviceOn, isLoading: entry.isLoading, size: 52, glyph: 22, colorScheme: colorScheme)

                    Spacer(minLength: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.nickname)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(brandInk(colorScheme))
                            .lineLimit(1)

                        Text("\(deviceStatus(isOnline: entry.isOnline, deviceOn: entry.deviceOn)) · \(entry.model)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(brandMuted(colorScheme))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(entry.isLoading)
            .accessibilityLabel("\(entry.nickname), \(deviceStatus(isOnline: entry.isOnline, deviceOn: entry.deviceOn))")
            .containerBackground(for: .widget) {
                brandBackground(colorScheme)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(brandAccent(colorScheme)))
                Text("Ajouter une prise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(brandInk(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Ouvrez Jolt pour commencer")
                    .font(.system(size: 11))
                    .foregroundColor(brandMuted(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .containerBackground(for: .widget) {
                brandBackground(colorScheme)
            }
        }
    }
}

struct JoltWidget: Widget {
    let kind: String = "JoltWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectDeviceIntent.self, provider: JoltWidgetProvider()) { entry in
            JoltWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tapo Plug")
        .description("Toggle a single Tapo smart plug.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - List Widgets

typealias ListDevice = (nickname: String, model: String, ip: String, deviceOn: Bool, isOnline: Bool, loadingUntil: Date?)

struct DeviceListEntry: TimelineEntry {
    var date: Date
    let devices: [ListDevice]
}

private var placeholderListEntry: DeviceListEntry { DeviceListEntry(date: Date(), devices: [
    (nickname: "Lampe Salon", model: "P110", ip: "192.168.1.1", deviceOn: true, isOnline: true, loadingUntil: nil),
    (nickname: "Bureau", model: "P100", ip: "192.168.1.2", deviceOn: false, isOnline: true, loadingUntil: nil),
]) }

private func loadListDevices() -> [ListDevice] {
    loadDevicesFromStorage().compactMap { device in
        guard let ip = device["ip"] as? String,
              let model = device["model"] as? String else { return nil }
        let nickname = device["nickname"] as? String ?? model
        let deviceOn = device["deviceOn"] as? Bool ?? false
        let isOnline = device["isOnline"] as? Bool ?? true
        return (nickname: nickname, model: model, ip: ip, deviceOn: deviceOn, isOnline: isOnline, loadingUntil: deviceLoadingDeadline(ip: ip))
    }
}

/// A timeline that stops each plug loading at its deadline, should the app
/// not reload the widget once the toggle ended.
private func listTimeline(_ entry: DeviceListEntry) -> Timeline<DeviceListEntry> {
    let deadlines = entry.devices.compactMap { $0.loadingUntil }
        .filter { showsLoading(until: $0, at: entry.date) }
    let settled = Set(deadlines).sorted().map { deadline in
        var later = entry
        later.date = deadline
        return later
    }
    return Timeline(entries: [entry] + settled, policy: .never)
}

/// The sizes of a plug row.
private struct PlugRowStyle {
    let nameSize: CGFloat
    /// How much a long name shrinks before it is truncated.
    let minNameScale: CGFloat
    let statusSize: CGFloat
    /// The space between the name and the status.
    let textSpacing: CGFloat
    let controlSize: CGFloat
    let glyphSize: CGFloat
    /// Whether the status is followed by the model.
    let showsModel: Bool
    /// Whether the whole height of the row toggles, rather than its content.
    let fillsRow: Bool

    static let compact = PlugRowStyle(nameSize: 13, minNameScale: 1, statusSize: 10, textSpacing: 1, controlSize: 28, glyphSize: 14, showsModel: true, fillsRow: false)
    static let roomy = PlugRowStyle(nameSize: 16, minNameScale: 1, statusSize: 12, textSpacing: 2, controlSize: 44, glyphSize: 18, showsModel: true, fillsRow: false)
    /// Two rows in a small widget: the width only fits a short status, and a
    /// tap between the two toggles should not open the app.
    static let square = PlugRowStyle(nameSize: 14, minNameScale: 0.8, statusSize: 11, textSpacing: 2, controlSize: 36, glyphSize: 16, showsModel: false, fillsRow: true)
}

/// A plug's name, status and toggle.
private struct PlugRow: View {
    let device: ListDevice
    let date: Date
    let style: PlugRowStyle
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let status = deviceStatus(isOnline: device.isOnline, deviceOn: device.deviceOn)
        let isLoading = showsLoading(until: device.loadingUntil, at: date)
        Button(intent: ToggleDeviceIntent(ip: device.ip)) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: style.textSpacing) {
                    Text(device.nickname)
                        .font(.system(size: style.nameSize, weight: .semibold))
                        .foregroundColor(brandInk(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(style.minNameScale)
                    Text(style.showsModel ? "\(status) · \(device.model)" : status)
                        .font(.system(size: style.statusSize, weight: .medium))
                        .foregroundColor(brandMuted(colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                powerControl(isOnline: device.isOnline, deviceOn: device.deviceOn, isLoading: isLoading, size: style.controlSize, glyph: style.glyphSize, colorScheme: colorScheme)
            }
            .frame(maxHeight: style.fillsRow ? .infinity : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel("\(device.nickname), \(status)")
        // Unless it fills the row, only the content toggles: the rest of a
        // tall row opens the app.
        .frame(maxHeight: .infinity)
    }
}

/// Plug rows sharing the height, with a separator between them.
private struct PlugRows: View {
    let devices: [ListDevice]
    let date: Date
    let style: PlugRowStyle
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(devices, id: \.ip) { device in
                PlugRow(device: device, date: date, style: style)
                    .overlay(alignment: .bottom) {
                        if device.ip != devices.last?.ip {
                            Rectangle()
                                .fill(brandOffSurface(colorScheme))
                                .frame(height: 0.5)
                        }
                    }
            }
        }
    }
}

private struct NoPlugView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "powerplug")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(brandAccent(colorScheme)))
            Text("Aucune prise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(brandInk(colorScheme))
            Text("Ajoutez une prise dans Jolt")
                .font(.system(size: 11))
                .foregroundColor(brandMuted(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - List Widget (All Plugs)

struct JoltListWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeviceListEntry {
        placeholderListEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (DeviceListEntry) -> Void) {
        completion(DeviceListEntry(date: Date(), devices: loadListDevices()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeviceListEntry>) -> Void) {
        completion(listTimeline(DeviceListEntry(date: Date(), devices: loadListDevices())))
    }
}

struct JoltListWidgetEntryView: View {
    var entry: DeviceListEntry
    @Environment(\.colorScheme) var colorScheme

    /// The shortest row that fits the name, the status and the control.
    private let minRowHeight: CGFloat = 28
    /// More rows would put the toggles of a large widget too close to tap.
    private let maxRows = 8
    /// Rows at least this tall get larger text and control.
    private let roomyRowHeight: CGFloat = 56

    var body: some View {
        Group {
            if entry.devices.isEmpty {
                NoPlugView()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Prises")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(brandInk(colorScheme))

                        Spacer()

                        Text("\(entry.devices.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(brandMuted(colorScheme))
                            .frame(width: 28, height: 24)
                            .background(Capsule().fill(brandOffSurface(colorScheme)))
                    }

                    // The rows share the height left by the header, as many as fit.
                    GeometryReader { proxy in
                        let visible = Array(entry.devices.prefix(min(maxRows, max(1, Int(proxy.size.height / minRowHeight)))))
                        let roomy = proxy.size.height / CGFloat(visible.count) >= roomyRowHeight
                        PlugRows(devices: visible, date: entry.date, style: roomy ? .roomy : .compact)
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            brandBackground(colorScheme)
        }
    }
}

struct JoltListWidget: Widget {
    let kind: String = "JoltListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JoltListWidgetProvider()) { entry in
            JoltListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tapo Plugs")
        .description("View and toggle all Tapo smart plugs.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Pair Widget (Two Plugs)

struct JoltPairWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DeviceListEntry {
        placeholderListEntry
    }

    func snapshot(for configuration: SelectDevicesIntent, in context: Context) async -> DeviceListEntry {
        getEntry(for: configuration)
    }

    func timeline(for configuration: SelectDevicesIntent, in context: Context) async -> Timeline<DeviceListEntry> {
        listTimeline(getEntry(for: configuration))
    }

    /// The selected plugs, then the first other ones for the rows left: two,
    /// as many as `SelectDevicesIntent` lets select.
    private func getEntry(for configuration: SelectDevicesIntent) -> DeviceListEntry {
        let selectedIps = (configuration.devices ?? []).map(\.id)
        let devices = loadListDevices()
        var rows: [ListDevice] = []
        // A plug selected twice only gets one row.
        for ip in selectedIps where !rows.contains(where: { $0.ip == ip }) {
            if let device = devices.first(where: { $0.ip == ip }) { rows.append(device) }
        }
        rows += devices.filter { !selectedIps.contains($0.ip) }
        return DeviceListEntry(date: Date(), devices: Array(rows.prefix(2)))
    }
}

struct JoltPairWidgetEntryView: View {
    var entry: DeviceListEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            if entry.devices.isEmpty {
                NoPlugView()
            } else {
                PlugRows(devices: entry.devices, date: entry.date, style: .square)
            }
        }
        .containerBackground(for: .widget) {
            brandBackground(colorScheme)
        }
    }
}

struct JoltPairWidget: Widget {
    let kind: String = "JoltPairWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectDevicesIntent.self, provider: JoltPairWidgetProvider()) { entry in
            JoltPairWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Two Tapo Plugs")
        .description("Toggle two Tapo smart plugs.")
        .supportedFamilies([.systemSmall])
    }
}
