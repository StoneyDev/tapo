import AppIntents
import WidgetKit

struct DeviceItem: AppEntity {
    let id: String
    let nickname: String
    let model: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Device"
    static var defaultQuery = DeviceQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(nickname)", subtitle: "\(model)")
    }
}

struct DeviceQuery: EntityQuery {
    func entities(for identifiers: [DeviceItem.ID]) async throws -> [DeviceItem] {
        let all = deviceItems()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [DeviceItem] {
        return deviceItems()
    }

    func defaultResult() async -> DeviceItem? {
        return deviceItems().first
    }

    private func deviceItems() -> [DeviceItem] {
        loadDevicesFromStorage().compactMap { device in
            guard let ip = device["ip"] as? String,
                  let model = device["model"] as? String else { return nil }
            let nickname = device["nickname"] as? String ?? model
            return DeviceItem(id: ip, nickname: nickname, model: model)
        }
    }
}

struct SelectDeviceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Device"
    static var description = IntentDescription("Select which Tapo plug to control.")

    @Parameter(title: "Device")
    var device: DeviceItem?
}
