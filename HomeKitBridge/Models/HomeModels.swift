import Foundation

/// Plain value types describing the parts of Apple Home the UI renders.
///
/// Views never see `HMHome`/`HMAccessory` directly: `HomeKitManager` derives these
/// summaries from HomeKit and publishes them, so screens stay renderable from
/// fixtures (previews and snapshot tests) and free of framework objects.

struct RoomSummary: Identifiable, Equatable, Codable {
    /// Name HomeKit gives the implicit room that holds unassigned accessories.
    static let defaultRoomName = "Default Room"

    let id: String
    let name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }

    var isDefaultRoom: Bool { name == Self.defaultRoomName }
}

struct CharacteristicSummary: Identifiable, Equatable, Codable {
    let id: String
    let type: String
    let value: String

    init(id: String = UUID().uuidString, type: String, value: String) {
        self.id = id
        self.type = type
        self.value = value
    }
}

struct ServiceSummary: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let type: String
    let characteristics: [CharacteristicSummary]

    init(id: String = UUID().uuidString, name: String, type: String, characteristics: [CharacteristicSummary] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.characteristics = characteristics
    }
}

struct AccessorySummary: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let roomId: String?
    let roomName: String
    let manufacturer: String?
    let model: String?
    let category: String
    let isReachable: Bool
    let isBlocked: Bool
    let isBridged: Bool
    /// `nil` until the serial number has been read from the accessory.
    var serialNumber: String?
    let services: [ServiceSummary]

    init(
        id: String = UUID().uuidString,
        name: String,
        roomId: String? = nil,
        roomName: String = RoomSummary.defaultRoomName,
        manufacturer: String? = nil,
        model: String? = nil,
        category: String = "Accessory",
        isReachable: Bool = true,
        isBlocked: Bool = false,
        isBridged: Bool = true,
        serialNumber: String? = nil,
        services: [ServiceSummary] = []
    ) {
        self.id = id
        self.name = name
        self.roomId = roomId
        self.roomName = roomName
        self.manufacturer = manufacturer
        self.model = model
        self.category = category
        self.isReachable = isReachable
        self.isBlocked = isBlocked
        self.isBridged = isBridged
        self.serialNumber = serialNumber
        self.services = services
    }

    /// The Home Assistant entity ID this accessory maps to, if it is bridged from
    /// Home Assistant (which writes the entity ID into the HomeKit serial number).
    ///
    /// A native accessory carries a real hardware serial there, so the shape is what
    /// tells the two apart: an entity ID is `domain.object_id`, lowercase, with one dot.
    var entityId: String? {
        guard let serialNumber else { return nil }
        let parts = serialNumber.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }

        let allowed = CharacterSet.lowercaseLetters.union(.decimalDigits).union(CharacterSet(charactersIn: "_"))
        guard serialNumber.replacingOccurrences(of: ".", with: "").unicodeScalars.allSatisfy(allowed.contains) else {
            return nil
        }
        return serialNumber
    }
}

struct HomeSummary: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    var rooms: [RoomSummary]
    var accessories: [AccessorySummary]

    init(id: String = UUID().uuidString, name: String, rooms: [RoomSummary] = [], accessories: [AccessorySummary] = []) {
        self.id = id
        self.name = name
        self.rooms = rooms
        self.accessories = accessories
    }

    func room(named name: String) -> RoomSummary? {
        rooms.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func accessory(id: String) -> AccessorySummary? {
        accessories.first { $0.id == id }
    }
}

/// What the bridge found in Home Assistant for one Apple Home accessory.
struct HomeAssistantMatch: Equatable {
    let entityId: String
    let friendlyName: String?
    let areaName: String?
    let deviceId: String?
    /// Pretty-printed registry payloads, rendered up-front so views never handle
    /// raw `[String: Any]` dictionaries.
    let stateJSON: String
    let entityJSON: String
    let deviceJSON: String?
    let areaJSON: String?

    init(
        entityId: String,
        friendlyName: String? = nil,
        areaName: String? = nil,
        deviceId: String? = nil,
        stateJSON: String = "{}",
        entityJSON: String = "{}",
        deviceJSON: String? = nil,
        areaJSON: String? = nil
    ) {
        self.entityId = entityId
        self.friendlyName = friendlyName
        self.areaName = areaName
        self.deviceId = deviceId
        self.stateJSON = stateJSON
        self.entityJSON = entityJSON
        self.deviceJSON = deviceJSON
        self.areaJSON = areaJSON
    }
}
