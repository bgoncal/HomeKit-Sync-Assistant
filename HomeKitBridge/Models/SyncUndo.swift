import Foundation

/// What it takes to put one applied change back the way it was.
///
/// Recorded just before each change is written, from the destination's state at
/// that moment, so an undo restores what was really there rather than what the
/// preview assumed.
enum UndoStep: Codable, Equatable {
    /// Apple Home: give an accessory its old name back.
    case renameAccessory(accessoryId: String, name: String)
    /// Apple Home: put an accessory back in the room it was in.
    case moveAccessory(accessoryId: String, roomId: String)
    /// Apple Home: remove a room the sync created.
    case removeRoom(roomId: String, name: String)
    /// Home Assistant: restore an entity's own name; `nil` is Home Assistant's default.
    case renameEntity(entityId: String, name: String?)
    /// Home Assistant: restore an entity's own area; `nil` means it follows its device.
    case setEntityArea(entityId: String, areaId: String?)
    /// Home Assistant: remove an area the sync created.
    case removeArea(areaId: String, name: String)
    /// Apple Home: remove a zone the sync created.
    case removeZone(zoneId: String, name: String)
    /// Apple Home: take a room back out of a zone it was added to.
    case removeRoomFromZone(roomId: String, zoneId: String)
    /// Home Assistant: remove a floor the sync created.
    case removeFloor(floorId: String, name: String)
    /// Home Assistant: put an area back on the floor it was on; `nil` for none.
    case setAreaFloor(areaId: String, floorId: String?)
    /// Apple Home: remove a scene the sync created.
    case removeScene(sceneId: String, name: String)
    /// Home Assistant: remove a scene the sync created, by its config ID.
    case removeHomeAssistantScene(configId: String, name: String)
}

/// The last sync that wrote anything, and how to reverse it.
struct SyncUndoRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let operation: SyncOperation
    let homeId: String
    let serverId: UUID
    /// The side that was written, by name, for "Undo changes in Casa".
    let destinationName: String
    let date: Date
    /// In the order they were applied; an undo walks them backwards.
    let steps: [UndoStep]

    init(id: UUID = UUID(), operation: SyncOperation, homeId: String, serverId: UUID, destinationName: String, date: Date = Date(), steps: [UndoStep]) {
        self.id = id
        self.operation = operation
        self.homeId = homeId
        self.serverId = serverId
        self.destinationName = destinationName
        self.date = date
        self.steps = steps
    }

    /// Local to this device on purpose: the steps name objects as this device last
    /// saw them, and undoing from a second device would race the first.
    static let defaultsKey = "lastSyncUndo"

    static func load(from defaults: UserDefaults) -> SyncUndoRecord? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SyncUndoRecord.self, from: data)
    }

    static func save(_ record: SyncUndoRecord?, to defaults: UserDefaults) {
        guard let record, let data = try? JSONEncoder().encode(record) else {
            defaults.removeObject(forKey: defaultsKey)
            return
        }
        defaults.set(data, forKey: defaultsKey)
    }
}
