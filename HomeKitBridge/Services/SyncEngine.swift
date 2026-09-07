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
enum SyncDirection: String, Codable {
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
        }
    }
}

/// What a sync operation keeps aligned.
enum SyncSubject: String, CaseIterable, Identifiable, Codable {
    case rooms
    case placement
    case names

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rooms: return "Rooms and areas"
        case .placement: return "Device placement"
        case .names: return "Device names"
        }
    }

    var symbolName: String {
        switch self {
        case .rooms: return "square.split.bottomrightquarter"
        case .placement: return "arrow.up.and.down.and.arrow.left.and.right"
        case .names: return "textformat"
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
        }
    }

    var subject: SyncSubject {
        switch self {
        case .roomsHAToHome, .roomsHomeToHA: return .rooms
        case .devicePlacementHAToHome, .devicePlacementHomeToHA: return .placement
        case .deviceNamesHAToHome, .deviceNamesHomeToHA: return .names
        }
    }

    var direction: SyncDirection {
        switch self {
        case .roomsHAToHome, .devicePlacementHAToHome, .deviceNamesHAToHome:
            return .homeAssistantToAppleHome
        case .roomsHomeToHA, .devicePlacementHomeToHA, .deviceNamesHomeToHA:
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
        }

        return "\(changeCount) \(noun). \(direction.source.name) will not change."
    }
}

// MARK: - Plans

struct DryRunResult: Identifiable, Equatable {
    let id: UUID
    let operation: SyncOperation
    /// The Apple Home this plan was made for, and with it the Home Assistant server.
    let homeId: String
    let summary: String
    let changes: [SyncChange]

    init(id: UUID = UUID(), operation: SyncOperation, homeId: String = "", summary: String, changes: [SyncChange]) {
        self.id = id
        self.operation = operation
        self.homeId = homeId
        self.summary = summary
        self.changes = changes
    }
}

enum SyncActionType: String {
    case createRoom
    case renameRoom
    case moveAccessory
    case renameAccessory
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

    init(id: UUID = UUID(), action: SyncActionType, title: String, details: String,
         accessoryId: String? = nil, roomId: String? = nil,
         newName: String? = nil, homeId: String? = nil,
         targetRoomName: String? = nil, extraData: [String: String]? = nil) {
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

    private let homeKitManager: HomeKitManager
    private let logStore: LogStore
    private let connections: ConnectionStore

    init(homeKitManager: HomeKitManager, logStore: LogStore, connections: ConnectionStore) {
        self.homeKitManager = homeKitManager
        self.logStore = logStore
        self.connections = connections
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

    func dryRun(_ operation: SyncOperation, homeId: String) async throws -> DryRunResult {
        isBusy = true
        progress = SyncProgress(title: "Preparing preview", detail: operation.displayTitle)
        defer {
            isBusy = false
            progress = nil
        }

        let context = try await context(forHomeId: homeId)

        progress = SyncProgress(title: "Comparing \(operation.direction.label)", detail: operation.displayTitle)
        switch operation {
        case .roomsHAToHome: return try await dryRunRoomsHAToHome(context)
        case .roomsHomeToHA: return try await dryRunRoomsHomeToHA(context)
        case .devicePlacementHAToHome: return try await dryRunDevicePlacementHAToHome(context)
        case .devicePlacementHomeToHA: return try await dryRunDevicePlacementHomeToHA(context)
        case .deviceNamesHAToHome: return try await dryRunDeviceNamesHAToHome(context)
        case .deviceNamesHomeToHA: return try await dryRunDeviceNamesHomeToHA(context)
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

        let context = try await context(forHomeId: result.homeId)

        logStore.add(
            category: .sync,
            message: "Applying: \(result.operation.displayTitle)",
            details: "\(result.changes.count) change\(result.changes.count == 1 ? "" : "s") in \(destinationName(for: result.operation, context: context))"
        )

        var successCount = 0
        var failCount = 0

        for (index, change) in result.changes.enumerated() {
            progress = SyncProgress(
                title: "Applying change \(index + 1) of \(result.changes.count)",
                detail: change.title,
                completed: index,
                total: result.changes.count
            )

            do {
                try await executeChange(change, operation: result.operation, context: context)
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

        logStore.add(
            category: .sync,
            message: "Finished: \(result.operation.displayTitle)",
            details: "\(successCount) applied, \(failCount) failed in \(destinationName(for: result.operation, context: context))"
        )
    }

    private func destinationName(for operation: SyncOperation, context: SyncContext) -> String {
        switch operation.direction.destination {
        case .appleHome: return context.home.name
        case .homeAssistant: return context.server.name
        }
    }

    private func executeChange(_ change: SyncChange, operation: SyncOperation, context: SyncContext) async throws {
        switch operation {
        case .roomsHAToHome:
            switch change.action {
            case .createRoom:
                guard let homeId = change.homeId, let name = change.newName else { return }
                _ = try await homeKitManager.createRoom(homeId: homeId, name: name)
            case .renameRoom:
                guard let roomId = change.roomId, let name = change.newName else { return }
                try await homeKitManager.renameRoom(id: roomId, newName: name)
            default: break
            }

        case .roomsHomeToHA:
            if change.action == .createRoom, let name = change.newName {
                _ = try await context.client.createArea(name: name)
            }

        case .devicePlacementHAToHome:
            switch change.action {
            case .createRoom:
                guard let homeId = change.homeId, let name = change.newName else { return }
                _ = try await homeKitManager.createRoom(homeId: homeId, name: name)
            case .moveAccessory:
                guard let accessoryId = change.accessoryId else { return }
                let home = homeKitManager.home(byId: context.home.id) ?? context.home
                let resolvedRoomId: String?
                if let existing = change.roomId {
                    resolvedRoomId = existing
                } else if let roomName = change.targetRoomName, let room = home.room(named: roomName) {
                    resolvedRoomId = room.id
                } else {
                    resolvedRoomId = nil
                }
                guard let roomId = resolvedRoomId else { return }
                try await homeKitManager.moveAccessory(id: accessoryId, toRoomId: roomId)
            default: break
            }

        case .devicePlacementHomeToHA:
            if change.action == .moveAccessory {
                guard let entityId = change.accessoryId, let targetArea = change.targetRoomName else { return }
                let areas = try await context.client.fetchAreas()
                var areaId: String?
                for area in areas {
                    if let name = area["name"] as? String, name.caseInsensitiveCompare(targetArea) == .orderedSame {
                        areaId = area["area_id"] as? String
                        break
                    }
                }
                if areaId == nil {
                    let result = try await context.client.createArea(name: targetArea)
                    areaId = (result["result"] as? [String: Any])?["area_id"] as? String
                }
                guard let finalAreaId = areaId else { return }
                _ = try await context.client.updateEntity(entityId: entityId, updates: ["area_id": finalAreaId])
            }

        case .deviceNamesHAToHome:
            if change.action == .renameAccessory {
                guard let accessoryId = change.accessoryId, let newName = change.newName else { return }
                try await homeKitManager.renameAccessory(id: accessoryId, newName: newName)
            }

        case .deviceNamesHomeToHA:
            if change.action == .renameAccessory {
                guard let entityId = change.accessoryId, let newName = change.newName else { return }
                _ = try await context.client.updateEntity(entityId: entityId, updates: ["name": newName])
            }
        }
    }

    // MARK: - Dry Run Implementations

    private func dryRunRoomsHAToHome(_ context: SyncContext) async throws -> DryRunResult {
        progress = SyncProgress(title: "Reading areas from \(context.server.name)")
        let areas = try await context.client.fetchAreas()
        var changes: [SyncChange] = []

        for (index, area) in areas.enumerated() {
            progress = SyncProgress(title: "Comparing areas with rooms", detail: "Area \(index + 1) of \(areas.count)", completed: index, total: areas.count)
            guard let name = area["name"] as? String else { continue }
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

        let rooms = context.home.rooms.filter { !$0.isDefaultRoom }
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
            guard let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id),
                  let targetAreaName = entityAreaMap[serial] else { continue }

            let currentRoomName = accessory.roomName
            if currentRoomName.caseInsensitiveCompare(targetAreaName) == .orderedSame { continue }

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
            guard let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id) else { continue }

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
            guard let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id),
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
            guard let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id),
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

    // MARK: - Home Assistant lookup

    /// Looks up everything the paired server knows about one bridged accessory,
    /// matching on the HomeKit serial number (which equals the entity ID).
    func homeAssistantMatch(forEntityId entityId: String, homeId: String) async throws -> HomeAssistantMatch? {
        let context = try await context(forHomeId: homeId)

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
            summary: operation.summary(changeCount: changes.count),
            changes: changes
        )
    }

    /// Resolves the home, its server, and an open connection — or explains which of
    /// the three is missing.
    private func context(forHomeId homeId: String) async throws -> SyncContext {
        guard let home = homeKitManager.home(byId: homeId) ?? homeKitManager.selectedHome else {
            throw BridgeError.notFound("No Apple Home is available yet. Allow HomeKit access, then pick a home.")
        }

        guard let server = connections.server(forHomeId: home.id) else {
            throw BridgeError.badRequest("“\(home.name)” is not linked to a Home Assistant server yet. Link it in Settings.")
        }

        guard let client = connections.client(forServerId: server.id) else {
            throw BridgeError.notFound("“\(server.name)” is no longer set up.")
        }

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
