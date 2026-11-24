import Foundation
import SwiftUI

// MARK: - Direction

/// The two systems the bridge moves information between.
enum SyncPlatform: String, Codable {
    case appleHome
    case homeAssistant

    var name: String {
        switch self {
        case .appleHome: return "Apple Home"
        case .homeAssistant: return "Home Assistant"
        }
    }

    var symbolName: String {
        switch self {
        case .appleHome: return "house.fill"
        case .homeAssistant: return "server.rack"
        }
    }
}

/// Which way information flows for a sync operation. Every screen that mentions a
/// sync shows this, so it is always obvious what gets read and what gets changed.
enum SyncDirection: String, CaseIterable, Hashable, Codable {
    case homeAssistantToAppleHome
    case appleHomeToHomeAssistant

    var source: SyncPlatform {
        switch self {
        case .homeAssistantToAppleHome: return .homeAssistant
        case .appleHomeToHomeAssistant: return .appleHome
        }
    }

    var destination: SyncPlatform {
        switch self {
        case .homeAssistantToAppleHome: return .appleHome
        case .appleHomeToHomeAssistant: return .homeAssistant
        }
    }

    /// "Home Assistant → Apple Home"
    var label: String { "\(source.name) → \(destination.name)" }

    /// One line spelling out which side is read and which side is written.
    var explanation: String {
        "Reads from \(source.name). Only \(destination.name) is changed."
    }

    /// The operation that syncs one subject in this direction.
    func operation(for subject: SyncSubject) -> SyncOperation {
        switch (subject, self) {
        case (.rooms, .homeAssistantToAppleHome): return .roomsHAToHome
        case (.rooms, .appleHomeToHomeAssistant): return .roomsHomeToHA
        case (.placement, .homeAssistantToAppleHome): return .devicePlacementHAToHome
        case (.placement, .appleHomeToHomeAssistant): return .devicePlacementHomeToHA
        case (.names, .homeAssistantToAppleHome): return .deviceNamesHAToHome
        case (.names, .appleHomeToHomeAssistant): return .deviceNamesHomeToHA
        case (.zones, .homeAssistantToAppleHome): return .zonesHAToHome
        case (.zones, .appleHomeToHomeAssistant): return .zonesHomeToHA
        case (.scenes, .homeAssistantToAppleHome): return .scenesHAToHome
        case (.scenes, .appleHomeToHomeAssistant): return .scenesHomeToHA
        }
    }
}

/// What a sync operation keeps aligned.
enum SyncSubject: String, CaseIterable, Identifiable, Hashable, Codable {
    case rooms
    case placement
    case names
    case zones
    case scenes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rooms: return "Rooms and areas"
        case .placement: return "Device placement"
        case .names: return "Device names"
        case .zones: return "Floors and zones"
        case .scenes: return "Scenes"
        }
    }

    var symbolName: String {
        switch self {
        case .rooms: return "square.split.bottomrightquarter"
        case .placement: return "arrow.up.and.down.and.arrow.left.and.right"
        case .names: return "textformat"
        case .zones: return "building.2"
        case .scenes: return "sparkles"
        }
    }
}

// MARK: - Operations

enum SyncOperation: String, CaseIterable, Identifiable, Codable {
    case roomsHAToHome = "rooms.homeAssistantToAppleHome"
    case roomsHomeToHA = "rooms.appleHomeToHomeAssistant"
    case devicePlacementHAToHome = "placement.homeAssistantToAppleHome"
    case devicePlacementHomeToHA = "placement.appleHomeToHomeAssistant"
    case deviceNamesHAToHome = "names.homeAssistantToAppleHome"
    case deviceNamesHomeToHA = "names.appleHomeToHomeAssistant"
    case zonesHAToHome = "zones.homeAssistantToAppleHome"
    case zonesHomeToHA = "zones.appleHomeToHomeAssistant"
    case scenesHAToHome = "scenes.homeAssistantToAppleHome"
    case scenesHomeToHA = "scenes.appleHomeToHomeAssistant"

    var id: String { rawValue }

    /// Raw values used before operations got stable identifiers. Kept so saved
    /// scheduled actions keep working after an update.
    static func operation(forStoredRawValue rawValue: String) -> SyncOperation? {
        if let operation = SyncOperation(rawValue: rawValue) { return operation }

        switch rawValue {
        case "Sync Rooms: HA → Apple Home": return .roomsHAToHome
        case "Sync Rooms: Apple Home → HA": return .roomsHomeToHA
        case "Sync Placement: HA → Apple Home": return .devicePlacementHAToHome
        case "Sync Placement: Apple Home → HA": return .devicePlacementHomeToHA
        case "Sync Names: HA → Apple Home": return .deviceNamesHAToHome
        case "Sync Names: Apple Home → HA": return .deviceNamesHomeToHA
        default: return nil
        }
    }

    /// The same thing to sync, the other way round. This is what the swap control
    /// on the Sync screen does, and it is always a valid operation.
    var inverted: SyncOperation {
        switch self {
        case .roomsHAToHome: return .roomsHomeToHA
        case .roomsHomeToHA: return .roomsHAToHome
        case .devicePlacementHAToHome: return .devicePlacementHomeToHA
        case .devicePlacementHomeToHA: return .devicePlacementHAToHome
        case .deviceNamesHAToHome: return .deviceNamesHomeToHA
        case .deviceNamesHomeToHA: return .deviceNamesHAToHome
        case .zonesHAToHome: return .zonesHomeToHA
        case .zonesHomeToHA: return .zonesHAToHome
        case .scenesHAToHome: return .scenesHomeToHA
        case .scenesHomeToHA: return .scenesHAToHome
        }
    }

    var subject: SyncSubject {
        switch self {
        case .roomsHAToHome, .roomsHomeToHA: return .rooms
        case .devicePlacementHAToHome, .devicePlacementHomeToHA: return .placement
        case .deviceNamesHAToHome, .deviceNamesHomeToHA: return .names
        case .zonesHAToHome, .zonesHomeToHA: return .zones
        case .scenesHAToHome, .scenesHomeToHA: return .scenes
        }
    }

    var direction: SyncDirection {
        switch self {
        case .roomsHAToHome, .devicePlacementHAToHome, .deviceNamesHAToHome, .zonesHAToHome, .scenesHAToHome:
            return .homeAssistantToAppleHome
        case .roomsHomeToHA, .devicePlacementHomeToHA, .deviceNamesHomeToHA, .zonesHomeToHA, .scenesHomeToHA:
            return .appleHomeToHomeAssistant
        }
    }

    /// Full sentence naming the change and the side that receives it.
    var displayTitle: String {
        switch self {
        case .roomsHAToHome:
            return "Create Apple Home rooms from Home Assistant areas"
        case .roomsHomeToHA:
            return "Create Home Assistant areas from Apple Home rooms"
        case .devicePlacementHAToHome:
            return "Move Apple Home devices into their Home Assistant areas"
        case .devicePlacementHomeToHA:
            return "Move Home Assistant entities into their Apple Home rooms"
        case .deviceNamesHAToHome:
            return "Rename Apple Home devices to their Home Assistant names"
        case .deviceNamesHomeToHA:
            return "Rename Home Assistant entities to their Apple Home names"
        case .zonesHAToHome:
            return "Group Apple Home rooms into zones from Home Assistant floors"
        case .zonesHomeToHA:
            return "Put Home Assistant areas on floors from Apple Home zones"
        case .scenesHAToHome:
            return "Create Apple Home scenes from Home Assistant scenes"
        case .scenesHomeToHA:
            return "Create Home Assistant scenes from Apple Home scenes"
        }
    }

    /// Compact label for pickers and rows, where the direction badge sits alongside.
    var shortTitle: String { subject.title }

    var description: String {
        switch self {
        case .roomsHAToHome:
            return "Each Home Assistant area without a matching Apple Home room is created in Apple Home. Existing rooms keep their names, and nothing in Home Assistant changes."
        case .roomsHomeToHA:
            return "Each Apple Home room without a matching Home Assistant area is created in Home Assistant. Existing areas keep their names, and nothing in Apple Home changes."
        case .devicePlacementHAToHome:
            return "Matched devices are moved into the Apple Home room that matches their Home Assistant area. Missing rooms are created first. Home Assistant is left untouched."
        case .devicePlacementHomeToHA:
            return "Matched entities are moved into the Home Assistant area that matches their Apple Home room. Missing areas are created first. Apple Home is left untouched."
        case .deviceNamesHAToHome:
            return "Matched Apple Home devices are renamed to their Home Assistant friendly name. Home Assistant names are not touched."
        case .deviceNamesHomeToHA:
            return "Matched Home Assistant entities are renamed to their Apple Home device name. Apple Home names are not touched."
        case .zonesHAToHome:
            return "Each Home Assistant floor becomes an Apple Home zone, and the rooms that match its areas are added to it. Rooms are never taken out of a zone, and Home Assistant is left untouched."
        case .zonesHomeToHA:
            return "Each Apple Home zone becomes a Home Assistant floor, and the areas that match its rooms are put on it. Apple Home is left untouched."
        case .scenesHAToHome:
            return "Each Home Assistant scene made in its scene editor, with no Apple Home scene of the same name, is created in Apple Home. Only lights and switches carry across: on or off, and brightness. Existing scenes are never changed."
        case .scenesHomeToHA:
            return "Each Apple Home scene with no Home Assistant scene of the same name is created in Home Assistant. Only lights and switches carry across: on or off, and brightness. Existing scenes are never changed."
        }
    }

    /// What the preview will list, phrased for the destination side.
    func summary(changeCount: Int) -> String {
        guard changeCount > 0 else {
            switch self {
            case .roomsHAToHome:
                return "Apple Home already has a room for every Home Assistant area."
            case .roomsHomeToHA:
                return "Home Assistant already has an area for every Apple Home room."
            case .devicePlacementHAToHome:
                return "Every matched device is already in the right Apple Home room."
            case .devicePlacementHomeToHA:
                return "Every matched entity is already in the right Home Assistant area."
            case .deviceNamesHAToHome:
                return "Every matched device already uses its Home Assistant name."
            case .deviceNamesHomeToHA:
                return "Every matched entity already uses its Apple Home name."
            case .zonesHAToHome:
                return "Apple Home already has a zone for every floor, with the same rooms in it."
            case .zonesHomeToHA:
                return "Home Assistant already has a floor for every zone, with the same areas on it."
            case .scenesHAToHome:
                return "Apple Home already has a scene for every Home Assistant scene it can carry across."
            case .scenesHomeToHA:
                return "Home Assistant already has a scene for every Apple Home scene it can carry across."
            }
        }

        let noun: String
        switch self {
        case .roomsHAToHome:
            noun = changeCount == 1 ? "room will be created in Apple Home" : "rooms will be created in Apple Home"
        case .roomsHomeToHA:
            noun = changeCount == 1 ? "area will be created in Home Assistant" : "areas will be created in Home Assistant"
        case .devicePlacementHAToHome:
            noun = changeCount == 1 ? "change will be made in Apple Home" : "changes will be made in Apple Home"
        case .devicePlacementHomeToHA:
            noun = changeCount == 1 ? "entity will be moved in Home Assistant" : "entities will be moved in Home Assistant"
        case .deviceNamesHAToHome:
            noun = changeCount == 1 ? "device will be renamed in Apple Home" : "devices will be renamed in Apple Home"
        case .deviceNamesHomeToHA:
            noun = changeCount == 1 ? "entity will be renamed in Home Assistant" : "entities will be renamed in Home Assistant"
        case .zonesHAToHome:
            noun = changeCount == 1 ? "change will be made in Apple Home" : "changes will be made in Apple Home"
        case .zonesHomeToHA:
            noun = changeCount == 1 ? "change will be made in Home Assistant" : "changes will be made in Home Assistant"
        case .scenesHAToHome:
            noun = changeCount == 1 ? "scene will be created in Apple Home" : "scenes will be created in Apple Home"
        case .scenesHomeToHA:
            noun = changeCount == 1 ? "scene will be created in Home Assistant" : "scenes will be created in Home Assistant"
        }

        return "\(changeCount) \(noun). \(direction.source.name) will not change."
    }
}

// MARK: - Plans

struct DryRunResult: Identifiable, Equatable {
    let id: UUID
    let operation: SyncOperation
    /// The pair this plan was made for, so applying it cannot land somewhere else.
    let homeId: String
    let serverId: UUID
    let summary: String
    let changes: [SyncChange]

    init(id: UUID = UUID(), operation: SyncOperation, homeId: String = "", serverId: UUID = UUID(), summary: String, changes: [SyncChange]) {
        self.id = id
        self.operation = operation
        self.homeId = homeId
        self.serverId = serverId
        self.summary = summary
        self.changes = changes
    }
}

extension DryRunResult {
    /// The same plan with only the changes the person kept ticked.
    func keeping(_ isIncluded: (SyncChange) -> Bool) -> DryRunResult {
        DryRunResult(
            id: id,
            operation: operation,
            homeId: homeId,
            serverId: serverId,
            summary: summary,
            changes: changes.filter(isIncluded)
        )
    }
}

enum SyncActionType: String {
    case createRoom
    case renameRoom
    case moveAccessory
    case renameAccessory
    /// An Apple Home zone or a Home Assistant floor.
    case createZone
    /// A room joins a zone, or an area moves onto a floor.
    case assignZone
    case createScene
    case unsupported
}

struct SyncChange: Identifiable, Equatable {
    let id: UUID
    let action: SyncActionType
    let title: String
    let details: String
    let accessoryId: String?
    let roomId: String?
    let newName: String?
    let homeId: String?
    let targetRoomName: String?
    let extraData: [String: String]?
    /// For a scene: what each Apple Home accessory does, and the entity it stands for.
    let sceneActions: [SceneAction]?
    let sceneEntityIds: [String: String]?

    init(id: UUID = UUID(), action: SyncActionType, title: String, details: String,
         accessoryId: String? = nil, roomId: String? = nil,
         newName: String? = nil, homeId: String? = nil,
         targetRoomName: String? = nil, extraData: [String: String]? = nil,
         sceneActions: [SceneAction]? = nil, sceneEntityIds: [String: String]? = nil) {
        self.sceneActions = sceneActions
        self.sceneEntityIds = sceneEntityIds
        self.id = id
        self.action = action
        self.title = title
        self.details = details
        self.accessoryId = accessoryId
        self.roomId = roomId
        self.newName = newName
        self.homeId = homeId
        self.targetRoomName = targetRoomName
        self.extraData = extraData
    }
}

struct SyncProgress: Equatable {
    let title: String
    let detail: String?
    let completed: Int?
    let total: Int?

    init(title: String, detail: String? = nil, completed: Int? = nil, total: Int? = nil) {
        self.title = title
        self.detail = detail
        self.completed = completed
        self.total = total
    }

    var fractionCompleted: Double? {
        guard let completed, let total, total > 0 else { return nil }
        return Double(completed) / Double(total)
    }
}

// MARK: - Engine

@MainActor
final class SyncEngine: ObservableObject {
    @Published private(set) var isBusy = false
    @Published private(set) var progress: SyncProgress?
    /// The last sync that wrote anything, kept until it is undone or replaced.
    @Published private(set) var lastUndo: SyncUndoRecord?

    private let homeKitManager: HomeKitManager
    private let logStore: LogStore
    private let connections: ConnectionStore
    private let preferences: SyncPreferencesStore
    private let defaults: UserDefaults

    init(
        homeKitManager: HomeKitManager,
        logStore: LogStore,
        connections: ConnectionStore,
        preferences: SyncPreferencesStore,
        defaults: UserDefaults = .standard
    ) {
        self.homeKitManager = homeKitManager
        self.logStore = logStore
        self.connections = connections
        self.preferences = preferences
        self.defaults = defaults
        self.lastUndo = SyncUndoRecord.load(from: defaults)
    }

    /// One Apple Home, the Home Assistant server it is paired with, and the open
    /// connection to it. Everything a sync needs, resolved once up front.
    private struct SyncContext {
        let home: HomeSummary
        let server: HomeAssistantServer
        let client: HAWebSocketClient
    }

    func testConnection(serverId: UUID) async -> Bool {
        let ok = await connections.connect(serverId: serverId)
        if !ok {
            logStore.add(
                category: .error,
                message: "Could not reach \(connections.server(id: serverId)?.name ?? "Home Assistant")",
                details: connections.state(forServerId: serverId).message ?? "Unknown error"
            )
        }
        return ok
    }

    // MARK: - Dry Run

    func dryRun(_ operation: SyncOperation, homeId: String, serverId: UUID) async throws -> DryRunResult {
        isBusy = true
        progress = SyncProgress(title: "Preparing preview", detail: operation.displayTitle)
        defer {
            isBusy = false
            progress = nil
        }

        let context = try await context(homeId: homeId, serverId: serverId)

        progress = SyncProgress(title: "Comparing \(operation.direction.label)", detail: operation.displayTitle)
        switch operation {
        case .roomsHAToHome: return try await dryRunRoomsHAToHome(context)
        case .roomsHomeToHA: return try await dryRunRoomsHomeToHA(context)
        case .devicePlacementHAToHome: return try await dryRunDevicePlacementHAToHome(context)
        case .devicePlacementHomeToHA: return try await dryRunDevicePlacementHomeToHA(context)
        case .deviceNamesHAToHome: return try await dryRunDeviceNamesHAToHome(context)
        case .deviceNamesHomeToHA: return try await dryRunDeviceNamesHomeToHA(context)
        case .zonesHAToHome: return try await dryRunZonesHAToHome(context)
        case .zonesHomeToHA: return try await dryRunZonesHomeToHA(context)
        case .scenesHAToHome: return try await dryRunScenesHAToHome(context)
        case .scenesHomeToHA: return try await dryRunScenesHomeToHA(context)
        }
    }

    // MARK: - Execute

    func execute(_ result: DryRunResult) async throws {
        isBusy = true
        progress = SyncProgress(title: "Preparing to apply", detail: result.operation.displayTitle)
        defer {
            isBusy = false
            progress = nil
        }

        let context = try await context(homeId: result.homeId, serverId: result.serverId)

        logStore.add(
            category: .sync,
            message: "Applying: \(result.operation.displayTitle)",
            details: "\(result.changes.count) change\(result.changes.count == 1 ? "" : "s") in \(destinationName(for: result.operation, context: context))"
        )

        var successCount = 0
        var failCount = 0
        var undoSteps: [UndoStep] = []

        // Home Assistant's own values are read once, so an undo can restore them.
        var registry: [String: [String: Any]] = [:]
        if result.operation.direction.destination == .homeAssistant {
            for entry in (try? await context.client.fetchEntityRegistry()) ?? [] {
                if let entityId = entry["entity_id"] as? String {
                    registry[entityId] = entry
                }
            }
        }

        for (index, change) in result.changes.enumerated() {
            progress = SyncProgress(
                title: "Applying change \(index + 1) of \(result.changes.count)",
                detail: change.title,
                completed: index,
                total: result.changes.count
            )

            do {
                undoSteps += try await executeChange(change, operation: result.operation, context: context, registry: registry)
                successCount += 1
                progress = SyncProgress(
                    title: "Applied change \(index + 1) of \(result.changes.count)",
                    detail: change.title,
                    completed: index + 1,
                    total: result.changes.count
                )
                logStore.add(category: .sync, message: "✓ \(change.title)", details: change.details)
            } catch {
                failCount += 1
                logStore.add(category: .error, message: "✗ \(change.title)", details: "\(change.details) — \(error.localizedDescription)")
            }
        }

        if !undoSteps.isEmpty {
            setLastUndo(SyncUndoRecord(
                operation: result.operation,
                homeId: context.home.id,
                serverId: context.server.id,
                destinationName: destinationName(for: result.operation, context: context),
                steps: undoSteps
            ))
        }

        logStore.add(
            category: .sync,
            message: "Finished: \(result.operation.displayTitle)",
            details: "\(successCount) applied, \(failCount) failed in \(destinationName(for: result.operation, context: context))"
        )
    }

    // MARK: - Undo

    /// Walks the last sync's steps backwards. Steps that no longer apply (a room
    /// deleted by hand since) are logged and skipped rather than stopping the rest.
    func undoLastSync() async throws {
        guard let record = lastUndo else { return }
        isBusy = true
        defer {
            isBusy = false
            progress = nil
        }

        let context = try await context(homeId: record.homeId, serverId: record.serverId)
        let steps = Array(record.steps.reversed())
        logStore.add(category: .sync, message: "Undoing: \(record.operation.displayTitle)", details: "\(steps.count) step\(steps.count == 1 ? "" : "s") in \(record.destinationName)")

        var failCount = 0
        for (index, step) in steps.enumerated() {
            progress = SyncProgress(title: "Undoing change \(index + 1) of \(steps.count)", completed: index, total: steps.count)
            do {
                try await perform(step, context: context)
            } catch {
                failCount += 1
                logStore.add(category: .error, message: "✗ Could not undo a change", details: error.localizedDescription)
            }
        }

        setLastUndo(nil)
        logStore.add(category: .sync, message: "Undone: \(record.operation.displayTitle)", details: "\(steps.count - failCount) restored, \(failCount) failed in \(record.destinationName)")
    }

    private func perform(_ step: UndoStep, context: SyncContext) async throws {
        switch step {
        case .renameAccessory(let accessoryId, let name):
            try await homeKitManager.renameAccessory(id: accessoryId, newName: name)
        case .moveAccessory(let accessoryId, let roomId):
            try await homeKitManager.moveAccessory(id: accessoryId, toRoomId: roomId)
        case .removeRoom(let roomId, _):
            try await homeKitManager.removeRoom(id: roomId)
        case .renameEntity(let entityId, let name):
            _ = try await context.client.updateEntity(entityId: entityId, updates: ["name": name.map { $0 as Any } ?? NSNull()])
        case .setEntityArea(let entityId, let areaId):
            _ = try await context.client.updateEntity(entityId: entityId, updates: ["area_id": areaId.map { $0 as Any } ?? NSNull()])
        case .removeArea(let areaId, _):
            try await context.client.deleteArea(areaId: areaId)
        case .removeZone(let zoneId, _):
            try await homeKitManager.removeZone(id: zoneId)
        case .removeRoomFromZone(let roomId, let zoneId):
            try await homeKitManager.removeRoom(id: roomId, fromZoneId: zoneId)
        case .removeFloor(let floorId, _):
            try await context.client.deleteFloor(floorId: floorId)
        case .setAreaFloor(let areaId, let floorId):
            try await context.client.setFloor(floorId, forAreaId: areaId)
        case .removeScene(let sceneId, _):
            try await homeKitManager.removeScene(id: sceneId)
        case .removeHomeAssistantScene(let configId, _):
            try await context.client.deleteSceneConfig(id: configId)
        }
    }

    private func setLastUndo(_ record: SyncUndoRecord?) {
        lastUndo = record
        SyncUndoRecord.save(record, to: defaults)
    }

    private func destinationName(for operation: SyncOperation, context: SyncContext) -> String {
        switch operation.direction.destination {
        case .appleHome: return context.home.name
        case .homeAssistant: return context.server.name
        }
    }

    /// Applies one change and returns what would reverse it.
    private func executeChange(
        _ change: SyncChange,
        operation: SyncOperation,
        context: SyncContext,
        registry: [String: [String: Any]]
    ) async throws -> [UndoStep] {
        switch operation {
        case .roomsHAToHome:
            switch change.action {
            case .createRoom:
                guard let homeId = change.homeId, let name = change.newName else { return [] }
                let room = try await homeKitManager.createRoom(homeId: homeId, name: name)
                return [.removeRoom(roomId: room.id, name: room.name)]
            case .renameRoom:
                guard let roomId = change.roomId, let name = change.newName else { return [] }
                try await homeKitManager.renameRoom(id: roomId, newName: name)
                return []
            default:
                return []
            }

        case .roomsHomeToHA:
            guard change.action == .createRoom, let name = change.newName else { return [] }
            let result = try await context.client.createArea(name: name)
            guard let areaId = (result["result"] as? [String: Any])?["area_id"] as? String else { return [] }
            return [.removeArea(areaId: areaId, name: name)]

        case .devicePlacementHAToHome:
            switch change.action {
            case .createRoom:
                guard let homeId = change.homeId, let name = change.newName else { return [] }
                // An earlier move may already have created it.
                if homeKitManager.home(byId: homeId)?.room(named: name) != nil { return [] }
                let room = try await homeKitManager.createRoom(homeId: homeId, name: name)
                return [.removeRoom(roomId: room.id, name: room.name)]
            case .moveAccessory:
                guard let accessoryId = change.accessoryId else { return [] }
                var steps: [UndoStep] = []
                let home = homeKitManager.home(byId: context.home.id) ?? context.home
                let resolvedRoomId: String
                if let existing = change.roomId {
                    resolvedRoomId = existing
                } else if let roomName = change.targetRoomName, let room = home.room(named: roomName) {
                    resolvedRoomId = room.id
                } else if let roomName = change.targetRoomName {
                    // The room's own "Create" row was unticked; the move still needs it.
                    let room = try await homeKitManager.createRoom(homeId: context.home.id, name: roomName)
                    steps.append(.removeRoom(roomId: room.id, name: room.name))
                    resolvedRoomId = room.id
                } else {
                    return []
                }
                let previousRoomId = homeKitManager.accessory(byId: accessoryId)?.roomId
                try await homeKitManager.moveAccessory(id: accessoryId, toRoomId: resolvedRoomId)
                if let previousRoomId {
                    steps.append(.moveAccessory(accessoryId: accessoryId, roomId: previousRoomId))
                }
                return steps
            default:
                return []
            }

        case .devicePlacementHomeToHA:
            guard change.action == .moveAccessory,
                  let entityId = change.accessoryId,
                  let targetArea = change.targetRoomName else { return [] }
            var steps: [UndoStep] = []
            let areas = try await context.client.fetchAreas()
            var areaId = areas.first {
                ($0["name"] as? String)?.caseInsensitiveCompare(targetArea) == .orderedSame
            }?["area_id"] as? String
            if areaId == nil {
                let result = try await context.client.createArea(name: targetArea)
                areaId = (result["result"] as? [String: Any])?["area_id"] as? String
                if let areaId {
                    steps.append(.removeArea(areaId: areaId, name: targetArea))
                }
            }
            guard let finalAreaId = areaId else { return steps }
            let previousAreaId = registry[entityId]?["area_id"] as? String
            _ = try await context.client.updateEntity(entityId: entityId, updates: ["area_id": finalAreaId])
            steps.append(.setEntityArea(entityId: entityId, areaId: previousAreaId))
            return steps

        case .deviceNamesHAToHome:
            guard change.action == .renameAccessory,
                  let accessoryId = change.accessoryId,
                  let newName = change.newName else { return [] }
            let previousName = homeKitManager.accessory(byId: accessoryId)?.name
            try await homeKitManager.renameAccessory(id: accessoryId, newName: newName)
            return previousName.map { [.renameAccessory(accessoryId: accessoryId, name: $0)] } ?? []

        case .deviceNamesHomeToHA:
            guard change.action == .renameAccessory,
                  let entityId = change.accessoryId,
                  let newName = change.newName else { return [] }
            let previousName = registry[entityId]?["name"] as? String
            _ = try await context.client.updateEntity(entityId: entityId, updates: ["name": newName])
            return [.renameEntity(entityId: entityId, name: previousName)]

        case .zonesHAToHome:
            return try await executeZoneChangeInAppleHome(change, context: context)

        case .zonesHomeToHA:
            return try await executeFloorChangeInHomeAssistant(change, context: context)

        case .scenesHAToHome:
            guard change.action == .createScene, let name = change.newName, let actions = change.sceneActions else { return [] }
            let scene = try await homeKitManager.createScene(homeId: context.home.id, name: name, actions: actions)
            return [.removeScene(sceneId: scene.id, name: scene.name)]

        case .scenesHomeToHA:
            guard change.action == .createScene,
                  let name = change.newName,
                  let actions = change.sceneActions,
                  let entityIds = change.sceneEntityIds else { return [] }
            var entities: [String: [String: Any]] = [:]
            for action in actions {
                guard let entityId = entityIds[action.accessoryId] else { continue }
                entities[entityId] = Self.homeAssistantState(for: action, entityId: entityId)
            }
            let configId = "homesync_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
            try await context.client.saveSceneConfig(id: configId, name: name, entities: entities)
            return [.removeHomeAssistantScene(configId: configId, name: name)]
        }
    }

    // MARK: - Scenes

    /// Home Assistant's state for one scene member. Brightness is 0–255 there, 0–100 in Apple Home.
    static func homeAssistantState(for action: SceneAction, entityId: String) -> [String: Any] {
        var state: [String: Any] = ["state": action.isOn == false ? "off" : "on"]
        if let brightness = action.brightness, entityId.hasPrefix("light."), action.isOn != false {
            state["brightness"] = Int((Double(brightness) / 100 * 255).rounded())
        }
        return state
    }

    /// The Apple Home action for one Home Assistant scene member, or `nil` when it
    /// is neither on nor off (a cover, a thermostat) and so cannot be carried across.
    static func sceneAction(accessoryId: String, homeAssistantState: [String: Any]) -> SceneAction? {
        let raw = homeAssistantState["state"] as? String
        guard raw == "on" || raw == "off" else { return nil }
        var action = SceneAction(accessoryId: accessoryId, isOn: raw == "on")
        if raw == "on", let brightness = (homeAssistantState["brightness"] as? NSNumber)?.doubleValue {
            action.brightness = Int((brightness / 255 * 100).rounded())
        }
        return action
    }

    /// Accessory ID → entity ID for every device a sync may touch in this home.
    private func entityIdsByAccessory(_ context: SyncContext) async -> [String: String] {
        var result: [String: String] = [:]
        for accessory in context.home.accessories {
            if let entityId = await entityId(for: accessory, homeId: context.home.id) {
                result[accessory.id] = entityId
            }
        }
        return result
    }

    private func dryRunScenesHAToHome(_ context: SyncContext) async throws -> DryRunResult {
        progress = SyncProgress(title: "Reading scenes from \(context.server.name)")
        let states = try await context.client.getStates()
        let accessoryByEntity = Dictionary(
            (await entityIdsByAccessory(context)).map { ($0.value, $0.key) },
            uniquingKeysWith: { first, _ in first }
        )

        var changes: [SyncChange] = []
        for state in states {
            guard let entityId = state["entity_id"] as? String, entityId.hasPrefix("scene."),
                  let attributes = state["attributes"] as? [String: Any],
                  let configId = attributes["id"] as? String else { continue }
            let name = (attributes["friendly_name"] as? String) ?? entityId
            if context.home.scene(named: name) != nil { continue }

            progress = SyncProgress(title: "Reading “\(name)”")
            guard let config = try await context.client.sceneConfig(id: configId),
                  let members = config["entities"] as? [String: [String: Any]] else { continue }

            let actions = members.compactMap { memberId, memberState in
                accessoryByEntity[memberId].flatMap { Self.sceneAction(accessoryId: $0, homeAssistantState: memberState) }
            }.sorted { $0.accessoryId < $1.accessoryId }
            guard !actions.isEmpty else { continue }

            changes.append(SyncChange(
                action: .createScene,
                title: "Create the scene “\(name)” in \(context.home.name)",
                details: "\(actions.count) of its \(members.count) device\(members.count == 1 ? "" : "s") carry across from \(context.server.name).",
                newName: name,
                homeId: context.home.id,
                sceneActions: actions
            ))
        }

        return result(.scenesHAToHome, context: context, changes: changes)
    }

    private func dryRunScenesHomeToHA(_ context: SyncContext) async throws -> DryRunResult {
        progress = SyncProgress(title: "Reading scenes from \(context.server.name)")
        let states = try await context.client.getStates()
        let existing = Set(states.compactMap { state -> String? in
            guard (state["entity_id"] as? String)?.hasPrefix("scene.") == true else { return nil }
            return ((state["attributes"] as? [String: Any])?["friendly_name"] as? String)?.lowercased()
        })
        let entityIds = await entityIdsByAccessory(context)

        var changes: [SyncChange] = []
        for scene in context.home.scenes where !existing.contains(scene.name.lowercased()) {
            let actions = scene.actions.filter { entityIds[$0.accessoryId] != nil }
            guard !actions.isEmpty else { continue }
            changes.append(SyncChange(
                action: .createScene,
                title: "Create the scene “\(scene.name)” in \(context.server.name)",
                details: "\(actions.count) of its \(scene.actions.count) device\(scene.actions.count == 1 ? "" : "s") carry across from \(context.home.name).",
                newName: scene.name,
                sceneActions: actions,
                sceneEntityIds: entityIds.filter { id, _ in actions.contains { $0.accessoryId == id } }
            ))
        }

        return result(.scenesHomeToHA, context: context, changes: changes)
    }

    // MARK: - Floors and zones

    private func executeZoneChangeInAppleHome(_ change: SyncChange, context: SyncContext) async throws -> [UndoStep] {
        guard let zoneName = change.targetRoomName else { return [] }
        let home = homeKitManager.home(byId: context.home.id) ?? context.home
        switch change.action {
        case .createZone:
            if home.zone(named: zoneName) != nil { return [] }
            let zone = try await homeKitManager.createZone(homeId: context.home.id, name: zoneName)
            return [.removeZone(zoneId: zone.id, name: zone.name)]
        case .assignZone:
            guard let roomId = change.roomId else { return [] }
            var steps: [UndoStep] = []
            let zoneId: String
            if let zone = home.zone(named: zoneName) {
                zoneId = zone.id
            } else {
                // The zone's own "Create" row was unticked; adding a room still needs it.
                let zone = try await homeKitManager.createZone(homeId: context.home.id, name: zoneName)
                steps.append(.removeZone(zoneId: zone.id, name: zone.name))
                zoneId = zone.id
            }
            try await homeKitManager.addRoom(id: roomId, toZoneId: zoneId)
            steps.append(.removeRoomFromZone(roomId: roomId, zoneId: zoneId))
            return steps
        default:
            return []
        }
    }

    private func executeFloorChangeInHomeAssistant(_ change: SyncChange, context: SyncContext) async throws -> [UndoStep] {
        guard let floorName = change.targetRoomName else { return [] }
        let floors = try await context.client.fetchFloors()
        let existing = floors.first {
            ($0["name"] as? String)?.caseInsensitiveCompare(floorName) == .orderedSame
        }?["floor_id"] as? String

        switch change.action {
        case .createZone:
            guard existing == nil, let floorId = try await context.client.createFloor(name: floorName) else { return [] }
            return [.removeFloor(floorId: floorId, name: floorName)]
        case .assignZone:
            guard let areaId = change.accessoryId else { return [] }
            var steps: [UndoStep] = []
            var floorId = existing
            if floorId == nil {
                floorId = try await context.client.createFloor(name: floorName)
                if let floorId { steps.append(.removeFloor(floorId: floorId, name: floorName)) }
            }
            guard let floorId else { return steps }
            let previous = change.extraData?["Previous floor"]
            try await context.client.setFloor(floorId, forAreaId: areaId)
            steps.append(.setAreaFloor(areaId: areaId, floorId: previous))
            return steps
        default:
            return []
        }
    }

    private func dryRunZonesHAToHome(_ context: SyncContext) async throws -> DryRunResult {
        progress = SyncProgress(title: "Reading floors from \(context.server.name)")
        let floors = try await context.client.fetchFloors()
        let areas = try await context.client.fetchAreas()

        var changes: [SyncChange] = []
        for floor in floors {
            guard let floorId = floor["floor_id"] as? String, let floorName = floor["name"] as? String else { continue }
            let zone = context.home.zone(named: floorName)
            if zone == nil {
                changes.append(SyncChange(
                    action: .createZone,
                    title: "Create the zone “\(floorName)” in \(context.home.name)",
                    details: "\(context.server.name) has the floor “\(floorName)”, \(context.home.name) has no zone with that name.",
                    homeId: context.home.id,
                    targetRoomName: floorName
                ))
            }

            let areaNames = areas
                .filter { ($0["floor_id"] as? String) == floorId }
                .compactMap { $0["name"] as? String }
                .filter { !preferences.isRoomExcluded(homeId: context.home.id, roomName: $0) }
            for areaName in areaNames {
                // Rooms are created by the Rooms sync; this one only groups them.
                guard let room = context.home.room(named: areaName) else { continue }
                if zone?.roomIds.contains(room.id) == true { continue }
                changes.append(SyncChange(
                    action: .assignZone,
                    title: "Add “\(room.name)” to the zone “\(floorName)”",
                    details: "Its area is on the floor “\(floorName)” in \(context.server.name).",
                    roomId: room.id,
                    homeId: context.home.id,
                    targetRoomName: floorName
                ))
            }
        }

        return result(.zonesHAToHome, context: context, changes: changes)
    }

    private func dryRunZonesHomeToHA(_ context: SyncContext) async throws -> DryRunResult {
        progress = SyncProgress(title: "Reading floors from \(context.server.name)")
        let floors = try await context.client.fetchFloors()
        let areas = try await context.client.fetchAreas()

        var floorNameById: [String: String] = [:]
        for floor in floors {
            if let id = floor["floor_id"] as? String, let name = floor["name"] as? String {
                floorNameById[id] = name
            }
        }

        var changes: [SyncChange] = []
        for zone in context.home.zones {
            if !floorNameById.values.contains(where: { $0.caseInsensitiveCompare(zone.name) == .orderedSame }) {
                changes.append(SyncChange(
                    action: .createZone,
                    title: "Create the floor “\(zone.name)” in \(context.server.name)",
                    details: "\(context.home.name) has the zone “\(zone.name)”, \(context.server.name) has no floor with that name.",
                    targetRoomName: zone.name
                ))
            }

            for roomId in zone.roomIds {
                guard let room = context.home.rooms.first(where: { $0.id == roomId }),
                      !preferences.isRoomExcluded(homeId: context.home.id, roomName: room.name),
                      let area = areas.first(where: { ($0["name"] as? String)?.caseInsensitiveCompare(room.name) == .orderedSame }),
                      let areaId = area["area_id"] as? String else { continue }
                let currentFloorId = area["floor_id"] as? String
                let currentFloor = currentFloorId.flatMap { floorNameById[$0] }
                if currentFloor?.caseInsensitiveCompare(zone.name) == .orderedSame { continue }

                var extra: [String: String] = [:]
                if let currentFloorId { extra["Previous floor"] = currentFloorId }
                changes.append(SyncChange(
                    action: .assignZone,
                    title: "Put “\(room.name)” on the floor “\(zone.name)”",
                    details: "Floor \(currentFloor ?? "None") → \(zone.name), to match its zone in \(context.home.name).",
                    accessoryId: areaId,
                    targetRoomName: zone.name,
                    extraData: extra
                ))
            }
        }

        return result(.zonesHomeToHA, context: context, changes: changes)
    }

    // MARK: - Dry Run Implementations

    private func dryRunRoomsHAToHome(_ context: SyncContext) async throws -> DryRunResult {
        progress = SyncProgress(title: "Reading areas from \(context.server.name)")
        let areas = try await context.client.fetchAreas()
        var changes: [SyncChange] = []

        for (index, area) in areas.enumerated() {
            progress = SyncProgress(title: "Comparing areas with rooms", detail: "Area \(index + 1) of \(areas.count)", completed: index, total: areas.count)
            guard let name = area["name"] as? String,
                  !preferences.isRoomExcluded(homeId: context.home.id, roomName: name) else { continue }
            if context.home.room(named: name) == nil {
                changes.append(SyncChange(
                    action: .createRoom,
                    title: "Create “\(name)” in \(context.home.name)",
                    details: "\(context.server.name) has the area “\(name)”, \(context.home.name) has no room with that name.",
                    newName: name,
                    homeId: context.home.id,
                    targetRoomName: name
                ))
            }
        }

        return result(.roomsHAToHome, context: context, changes: changes)
    }

    private func dryRunRoomsHomeToHA(_ context: SyncContext) async throws -> DryRunResult {
        progress = SyncProgress(title: "Reading areas from \(context.server.name)")
        let areas = try await context.client.fetchAreas()
        let areaNames = Set(areas.compactMap { ($0["name"] as? String)?.lowercased() })

        let rooms = context.home.rooms.filter {
            !$0.isDefaultRoom && !preferences.isRoomExcluded(homeId: context.home.id, roomName: $0.name)
        }
        var changes: [SyncChange] = []
        for (index, room) in rooms.enumerated() {
            progress = SyncProgress(title: "Comparing rooms with areas", detail: "Room \(index + 1) of \(rooms.count)", completed: index, total: rooms.count)
            if !areaNames.contains(room.name.lowercased()) {
                changes.append(SyncChange(
                    action: .createRoom,
                    title: "Create “\(room.name)” in \(context.server.name)",
                    details: "\(context.home.name) has the room “\(room.name)”, \(context.server.name) has no area with that name.",
                    roomId: room.id,
                    newName: room.name,
                    targetRoomName: room.name
                ))
            }
        }

        return result(.roomsHomeToHA, context: context, changes: changes)
    }

    private func dryRunDevicePlacementHAToHome(_ context: SyncContext) async throws -> DryRunResult {
        let entityAreaMap = try await buildEntityAreaMap(context)
        var changes: [SyncChange] = []
        var plannedRoomCreates = Set<String>()

        for (index, accessory) in context.home.accessories.enumerated() {
            progress = SyncProgress(title: "Matching devices", detail: "Device \(index + 1) of \(context.home.accessories.count): \(accessory.name)", completed: index, total: context.home.accessories.count)
            guard let serial = await entityId(for: accessory, homeId: context.home.id),
                  let targetAreaName = entityAreaMap[serial] else { continue }

            let currentRoomName = accessory.roomName
            if currentRoomName.caseInsensitiveCompare(targetAreaName) == .orderedSame { continue }
            // Never move a device into a room the person asked every sync to leave alone.
            if preferences.isRoomExcluded(homeId: context.home.id, roomName: targetAreaName) { continue }

            let existingRoom = context.home.room(named: targetAreaName)
            if existingRoom == nil, !plannedRoomCreates.contains(targetAreaName.lowercased()) {
                plannedRoomCreates.insert(targetAreaName.lowercased())
                changes.append(SyncChange(
                    action: .createRoom,
                    title: "Create “\(targetAreaName)” in \(context.home.name)",
                    details: "Needed before devices can be moved into it.",
                    newName: targetAreaName,
                    homeId: context.home.id,
                    targetRoomName: targetAreaName
                ))
            }

            changes.append(SyncChange(
                action: .moveAccessory,
                title: "Move “\(accessory.name)” in \(context.home.name)",
                details: "Room \(currentRoomName.isEmpty ? RoomSummary.defaultRoomName : currentRoomName) → \(targetAreaName), to match its area in \(context.server.name).",
                accessoryId: accessory.id,
                roomId: existingRoom?.id,
                targetRoomName: targetAreaName,
                extraData: ["Entity": serial]
            ))
        }

        return result(.devicePlacementHAToHome, context: context, changes: changes)
    }

    private func dryRunDevicePlacementHomeToHA(_ context: SyncContext) async throws -> DryRunResult {
        let entityAreaMap = try await buildEntityAreaMap(context)
        var changes: [SyncChange] = []

        for (index, accessory) in context.home.accessories.enumerated() {
            progress = SyncProgress(title: "Matching devices", detail: "Device \(index + 1) of \(context.home.accessories.count): \(accessory.name)", completed: index, total: context.home.accessories.count)
            guard let serial = await entityId(for: accessory, homeId: context.home.id) else { continue }

            let roomName = accessory.roomName
            guard roomName != RoomSummary.defaultRoomName, !roomName.isEmpty else { continue }

            let areaName = entityAreaMap[serial] ?? ""
            if roomName.caseInsensitiveCompare(areaName) == .orderedSame { continue }

            changes.append(SyncChange(
                action: .moveAccessory,
                title: "Move “\(accessory.name)” in \(context.server.name)",
                details: "Area \(areaName.isEmpty ? "None" : areaName) → \(roomName), to match its room in \(context.home.name).",
                accessoryId: serial,
                targetRoomName: roomName,
                extraData: ["Entity": serial]
            ))
        }

        return result(.devicePlacementHomeToHA, context: context, changes: changes)
    }

    private func dryRunDeviceNamesHAToHome(_ context: SyncContext) async throws -> DryRunResult {
        let nameMap = try await buildEntityNameMap(context)
        var changes: [SyncChange] = []

        for (index, accessory) in context.home.accessories.enumerated() {
            progress = SyncProgress(title: "Matching devices", detail: "Device \(index + 1) of \(context.home.accessories.count): \(accessory.name)", completed: index, total: context.home.accessories.count)
            guard let serial = await entityId(for: accessory, homeId: context.home.id),
                  let targetName = nameMap[serial] else { continue }
            if accessory.name == targetName { continue }

            changes.append(SyncChange(
                action: .renameAccessory,
                title: "Rename “\(accessory.name)” in \(context.home.name)",
                details: "Name \(accessory.name) → \(targetName), taken from \(context.server.name).",
                accessoryId: accessory.id,
                newName: targetName,
                extraData: ["Entity": serial]
            ))
        }

        return result(.deviceNamesHAToHome, context: context, changes: changes)
    }

    private func dryRunDeviceNamesHomeToHA(_ context: SyncContext) async throws -> DryRunResult {
        let nameMap = try await buildEntityNameMap(context)
        var changes: [SyncChange] = []

        for (index, accessory) in context.home.accessories.enumerated() {
            progress = SyncProgress(title: "Matching devices", detail: "Device \(index + 1) of \(context.home.accessories.count): \(accessory.name)", completed: index, total: context.home.accessories.count)
            guard let serial = await entityId(for: accessory, homeId: context.home.id),
                  let haName = nameMap[serial] else { continue }
            if accessory.name == haName { continue }

            changes.append(SyncChange(
                action: .renameAccessory,
                title: "Rename “\(haName)” in \(context.server.name)",
                details: "Name \(haName) → \(accessory.name), taken from \(context.home.name).",
                accessoryId: serial,
                newName: accessory.name,
                extraData: ["Entity": serial]
            ))
        }

        return result(.deviceNamesHomeToHA, context: context, changes: changes)
    }

    // MARK: - Differences

    /// Everything that differs between one home and one server, without writing.
    func differences(homeId: String, serverId: UUID) async throws -> PairDifferences {
        isBusy = true
        defer {
            isBusy = false
            progress = nil
        }

        let context = try await context(homeId: homeId, serverId: serverId)
        progress = SyncProgress(title: "Reading \(context.server.name)")
        let areas = try await context.client.fetchAreas()
        let areaMap = try await buildEntityAreaMap(context)
        let nameMap = try await buildEntityNameMap(context)

        var result = PairDifferences(homeName: context.home.name, serverName: context.server.name)
        let areaNames = areas.compactMap { $0["name"] as? String }
            .filter { !preferences.isRoomExcluded(homeId: context.home.id, roomName: $0) }
        let roomNames = context.home.rooms.filter {
            !$0.isDefaultRoom && !preferences.isRoomExcluded(homeId: context.home.id, roomName: $0.name)
        }.map(\.name)

        let lowercasedAreas = Set(areaNames.map { $0.lowercased() })
        let lowercasedRooms = Set(roomNames.map { $0.lowercased() })
        result.roomsOnlyInAppleHome = roomNames.filter { !lowercasedAreas.contains($0.lowercased()) }.sorted()
        result.areasOnlyInHomeAssistant = areaNames.filter { !lowercasedRooms.contains($0.lowercased()) }.sorted()

        let accessories = context.home.accessories.filter { !preferences.isExcluded($0, homeId: context.home.id) }
        for (index, accessory) in accessories.enumerated() {
            progress = SyncProgress(title: "Comparing devices", detail: accessory.name, completed: index, total: accessories.count)
            guard let entityId = await entityId(for: accessory, homeId: context.home.id),
                  let haName = nameMap[entityId] else {
                result.unmatchedDevices.append(accessory.name)
                continue
            }

            var agrees = true
            let area = areaMap[entityId] ?? ""
            if accessory.roomName.caseInsensitiveCompare(area) != .orderedSame {
                agrees = false
                result.differentRoom.append(DeviceDifference(
                    id: accessory.id,
                    deviceName: accessory.name,
                    appleHomeValue: accessory.roomName,
                    homeAssistantValue: area.isEmpty ? "No area" : area
                ))
            }
            if accessory.name != haName {
                agrees = false
                result.differentName.append(DeviceDifference(
                    id: accessory.id,
                    deviceName: accessory.name,
                    appleHomeValue: accessory.name,
                    homeAssistantValue: haName
                ))
            }
            if agrees { result.matchingCount += 1 }
        }

        result.unmatchedDevices.sort { $0.localizedCompare($1) == .orderedAscending }
        return result
    }

    // MARK: - Matching

    /// The Home Assistant entity a device stands for: the one picked by hand, else
    /// the entity ID HomeKit Bridge writes into the serial number. `nil` when the
    /// device or its room is excluded, or it is not bridged at all.
    private func entityId(for accessory: AccessorySummary, homeId: String) async -> String? {
        guard !preferences.isExcluded(accessory, homeId: homeId) else { return nil }
        if let manual = preferences.manualEntityId(forAccessoryId: accessory.id) { return manual }
        return await homeKitManager.refreshSerialNumber(accessoryId: accessory.id)
    }

    // MARK: - Home Assistant lookup

    /// Looks up everything the paired server knows about one bridged accessory,
    /// matching on the HomeKit serial number (which equals the entity ID).
    func homeAssistantMatch(forEntityId entityId: String, homeId: String, serverId: UUID) async throws -> HomeAssistantMatch? {
        let context = try await context(homeId: homeId, serverId: serverId)

        async let statesTask = context.client.getStates()
        async let entitiesTask = context.client.fetchEntityRegistry()
        async let devicesTask = context.client.fetchDeviceRegistry()
        async let areasTask = context.client.fetchAreas()

        let states = try await statesTask
        let entities = try await entitiesTask
        let devices = try await devicesTask
        let areas = try await areasTask

        guard let state = states.first(where: { ($0["entity_id"] as? String) == entityId }) else { return nil }
        let entity = entities.first { ($0["entity_id"] as? String) == entityId }

        let deviceId = entity?["device_id"] as? String
        let device = deviceId.flatMap { id in devices.first { ($0["id"] as? String) == id } }
        let areaId = (entity?["area_id"] as? String) ?? (device?["area_id"] as? String)
        let area = areaId.flatMap { id in areas.first { ($0["area_id"] as? String) == id } }

        return HomeAssistantMatch(
            entityId: entityId,
            friendlyName: (state["attributes"] as? [String: Any])?["friendly_name"] as? String,
            areaName: area?["name"] as? String,
            deviceId: deviceId,
            serverName: context.server.name,
            stateJSON: Self.prettyJSON(state),
            entityJSON: Self.prettyJSON(entity ?? [:]),
            deviceJSON: device.map(Self.prettyJSON),
            areaJSON: area.map(Self.prettyJSON)
        )
    }

    /// Everything one server exposes, grouped the way Home Assistant groups it.
    func entities(forServerId serverId: UUID) async throws -> [EntityArea] {
        guard let server = connections.server(id: serverId), let client = connections.client(forServerId: serverId) else {
            throw BridgeError.notFound("That Home Assistant is no longer set up.")
        }

        if !client.isConnected {
            let ok = await connections.connect(serverId: serverId)
            if !ok {
                throw BridgeError.badRequest(
                    connections.state(forServerId: serverId).message ?? "Could not connect to \(server.name)."
                )
            }
        }

        async let statesTask = client.getStates()
        async let entitiesTask = client.fetchEntityRegistry()
        async let devicesTask = client.fetchDeviceRegistry()
        async let areasTask = client.fetchAreas()

        let states = try await statesTask
        let registry = try await entitiesTask
        let devices = try await devicesTask
        let areas = try await areasTask

        var areaNameById: [String: String] = [:]
        for area in areas {
            if let id = area["area_id"] as? String, let name = area["name"] as? String {
                areaNameById[id] = name
            }
        }

        var deviceAreaById: [String: String] = [:]
        for device in devices {
            if let id = device["id"] as? String, let areaId = device["area_id"] as? String {
                deviceAreaById[id] = areaId
            }
        }

        var areaNameByEntity: [String: String] = [:]
        for entity in registry {
            guard let entityId = entity["entity_id"] as? String else { continue }
            let areaId = (entity["area_id"] as? String) ?? (entity["device_id"] as? String).flatMap { deviceAreaById[$0] }
            if let areaId, let name = areaNameById[areaId] {
                areaNameByEntity[entityId] = name
            }
        }

        var grouped: [String: [EntitySummary]] = [:]
        for state in states {
            guard let entityId = state["entity_id"] as? String else { continue }
            let attributes = state["attributes"] as? [String: Any]
            let entity = EntitySummary(
                entityId: entityId,
                name: (attributes?["friendly_name"] as? String) ?? entityId,
                state: (state["state"] as? String) ?? "unknown"
            )
            grouped[areaNameByEntity[entityId] ?? EntityArea.unassignedName, default: []].append(entity)
        }

        return grouped
            .map { EntityArea(name: $0.key, entities: $0.value.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) }
            .sorted { left, right in
                // Everything without an area goes last; the rest read alphabetically.
                if left.name == EntityArea.unassignedName { return false }
                if right.name == EntityArea.unassignedName { return true }
                return left.name.localizedCompare(right.name) == .orderedAscending
            }
    }

    static func prettyJSON(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    // MARK: - Helpers

    private func result(_ operation: SyncOperation, context: SyncContext, changes: [SyncChange]) -> DryRunResult {
        DryRunResult(
            operation: operation,
            homeId: context.home.id,
            serverId: context.server.id,
            summary: operation.summary(changeCount: changes.count),
            changes: changes
        )
    }

    /// Resolves the chosen pair and an open connection — or explains what is missing.
    private func context(homeId: String, serverId: UUID) async throws -> SyncContext {
        guard let home = homeKitManager.home(byId: homeId) ?? homeKitManager.selectedHome else {
            throw BridgeError.notFound("No Apple Home is available yet. Allow HomeKit access, then pick a home.")
        }

        guard let server = connections.server(id: serverId) else {
            throw BridgeError.notFound("That Home Assistant is no longer set up.")
        }

        guard let client = connections.client(forServerId: server.id) else {
            throw BridgeError.notFound("“\(server.name)” is no longer set up.")
        }

        // The pair that just worked is the one to offer next time.
        connections.rememberPairing(homeId: home.id, serverId: server.id)

        if !client.isConnected {
            progress = SyncProgress(title: "Connecting to \(server.name)", detail: server.normalizedAddress)
            let ok = await connections.connect(serverId: server.id)
            if !ok {
                throw BridgeError.badRequest(
                    connections.state(forServerId: server.id).message ?? "Could not connect to \(server.name)."
                )
            }
        }

        return SyncContext(home: home, server: server, client: client)
    }

    private func buildEntityAreaMap(_ context: SyncContext) async throws -> [String: String] {
        progress = SyncProgress(title: "Reading areas from \(context.server.name)")
        let areas = try await context.client.fetchAreas()
        progress = SyncProgress(title: "Reading entities from \(context.server.name)")
        let entities = try await context.client.fetchEntityRegistry()
        progress = SyncProgress(title: "Reading devices from \(context.server.name)")
        let devices = try await context.client.fetchDeviceRegistry()

        var areaNameById: [String: String] = [:]
        for area in areas {
            if let id = area["area_id"] as? String, let name = area["name"] as? String {
                areaNameById[id] = name
            }
        }

        var deviceAreaById: [String: String] = [:]
        for device in devices {
            if let id = device["id"] as? String, let areaId = device["area_id"] as? String {
                deviceAreaById[id] = areaId
            }
        }

        var result: [String: String] = [:]
        for entity in entities {
            guard let entityId = entity["entity_id"] as? String else { continue }
            let entityAreaId = entity["area_id"] as? String
            let deviceId = entity["device_id"] as? String
            let deviceAreaId = deviceId.flatMap { deviceAreaById[$0] }
            let areaId = entityAreaId ?? deviceAreaId
            if let areaId, let areaName = areaNameById[areaId] {
                result[entityId] = areaName
            }
        }

        return result
    }

    private func buildEntityNameMap(_ context: SyncContext) async throws -> [String: String] {
        progress = SyncProgress(title: "Reading names from \(context.server.name)")
        let states = try await context.client.getStates()
        var result: [String: String] = [:]
        for state in states {
            if let entityId = state["entity_id"] as? String,
               let attributes = state["attributes"] as? [String: Any],
               let friendlyName = attributes["friendly_name"] as? String {
                result[entityId] = friendlyName
            }
        }
        return result
    }
}
