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
}

/// What a sync operation keeps aligned.
enum SyncSubject: String, Codable {
    case rooms
    case placement
    case names

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
    let summary: String
    let changes: [SyncChange]

    init(id: UUID = UUID(), operation: SyncOperation, summary: String, changes: [SyncChange]) {
        self.id = id
        self.operation = operation
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
    private let wsClient: HAWebSocketClient

    init(homeKitManager: HomeKitManager, logStore: LogStore, wsClient: HAWebSocketClient) {
        self.homeKitManager = homeKitManager
        self.logStore = logStore
        self.wsClient = wsClient
    }

    func testHAConnection() async -> Bool {
        if wsClient.isConnected {
            return true
        }

        let ok = await wsClient.connect()
        if !ok {
            logStore.add(
                category: .error,
                message: "Could not reach Home Assistant",
                details: wsClient.connectionError ?? "Unknown error"
            )
        }
        return ok
    }

    // MARK: - Dry Run

    func dryRun(_ operation: SyncOperation) async throws -> DryRunResult {
        isBusy = true
        progress = SyncProgress(title: "Preparing preview", detail: operation.displayTitle)
        defer {
            isBusy = false
            progress = nil
        }

        try await ensureConnected()

        progress = SyncProgress(title: "Comparing \(operation.direction.label)", detail: operation.displayTitle)
        switch operation {
        case .roomsHAToHome: return try await dryRunRoomsHAToHome()
        case .roomsHomeToHA: return try await dryRunRoomsHomeToHA()
        case .devicePlacementHAToHome: return try await dryRunDevicePlacementHAToHome()
        case .devicePlacementHomeToHA: return try await dryRunDevicePlacementHomeToHA()
        case .deviceNamesHAToHome: return try await dryRunDeviceNamesHAToHome()
        case .deviceNamesHomeToHA: return try await dryRunDeviceNamesHomeToHA()
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

        try await ensureConnected()

        logStore.add(
            category: .sync,
            message: "Applying: \(result.operation.displayTitle)",
            details: "\(result.changes.count) change\(result.changes.count == 1 ? "" : "s") in \(result.operation.direction.destination.name)"
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
                try await executeChange(change, operation: result.operation)
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
            details: "\(successCount) applied, \(failCount) failed in \(result.operation.direction.destination.name)"
        )
    }

    private func ensureConnected() async throws {
        guard !wsClient.isConnected else { return }
        progress = SyncProgress(title: "Connecting to Home Assistant", detail: "Opening the WebSocket connection")
        let ok = await wsClient.connect()
        if !ok {
            throw BridgeError.badRequest(wsClient.connectionError ?? "Could not connect to Home Assistant")
        }
    }

    private func executeChange(_ change: SyncChange, operation: SyncOperation) async throws {
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
                _ = try await wsClient.createArea(name: name)
            }

        case .devicePlacementHAToHome:
            switch change.action {
            case .createRoom:
                guard let homeId = change.homeId, let name = change.newName else { return }
                _ = try await homeKitManager.createRoom(homeId: homeId, name: name)
            case .moveAccessory:
                guard let accessoryId = change.accessoryId, let home = homeKitManager.selectedHome else { return }
                let resolvedRoomId: String?
                if let existing = change.roomId {
                    resolvedRoomId = existing
                } else if let roomName = change.targetRoomName,
                          let room = home.room(named: roomName) {
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
                let areas = try await wsClient.fetchAreas()
                var areaId: String?
                for area in areas {
                    if let name = area["name"] as? String, name.caseInsensitiveCompare(targetArea) == .orderedSame {
                        areaId = area["area_id"] as? String
                        break
                    }
                }
                if areaId == nil {
                    let result = try await wsClient.createArea(name: targetArea)
                    areaId = (result["result"] as? [String: Any])?["area_id"] as? String
                }
                guard let finalAreaId = areaId else { return }
                _ = try await wsClient.updateEntity(entityId: entityId, updates: ["area_id": finalAreaId])
            }

        case .deviceNamesHAToHome:
            if change.action == .renameAccessory {
                guard let accessoryId = change.accessoryId, let newName = change.newName else { return }
                try await homeKitManager.renameAccessory(id: accessoryId, newName: newName)
            }

        case .deviceNamesHomeToHA:
            if change.action == .renameAccessory {
                guard let entityId = change.accessoryId, let newName = change.newName else { return }
                _ = try await wsClient.updateEntity(entityId: entityId, updates: ["name": newName])
            }
        }
    }

    // MARK: - Dry Run Implementations

    private func dryRunRoomsHAToHome() async throws -> DryRunResult {
        let home = try selectedHome()
        progress = SyncProgress(title: "Reading Home Assistant areas")
        let areas = try await wsClient.fetchAreas()
        var changes: [SyncChange] = []

        for (index, area) in areas.enumerated() {
            progress = SyncProgress(title: "Comparing areas with Apple Home rooms", detail: "Area \(index + 1) of \(areas.count)", completed: index, total: areas.count)
            guard let name = area["name"] as? String else { continue }
            if home.room(named: name) == nil {
                changes.append(SyncChange(
                    action: .createRoom,
                    title: "Create “\(name)” in Apple Home",
                    details: "Home Assistant has the area “\(name)”, Apple Home has no room with that name.",
                    newName: name,
                    homeId: home.id,
                    targetRoomName: name
                ))
            }
        }

        return DryRunResult(
            operation: .roomsHAToHome,
            summary: SyncOperation.roomsHAToHome.summary(changeCount: changes.count),
            changes: changes
        )
    }

    private func dryRunRoomsHomeToHA() async throws -> DryRunResult {
        let home = try selectedHome()
        progress = SyncProgress(title: "Reading Home Assistant areas")
        let areas = try await wsClient.fetchAreas()
        let areaNames = Set(areas.compactMap { ($0["name"] as? String)?.lowercased() })

        let rooms = home.rooms.filter { !$0.isDefaultRoom }
        var changes: [SyncChange] = []
        for (index, room) in rooms.enumerated() {
            progress = SyncProgress(title: "Comparing Apple Home rooms with areas", detail: "Room \(index + 1) of \(rooms.count)", completed: index, total: rooms.count)
            if !areaNames.contains(room.name.lowercased()) {
                changes.append(SyncChange(
                    action: .createRoom,
                    title: "Create “\(room.name)” in Home Assistant",
                    details: "Apple Home has the room “\(room.name)”, Home Assistant has no area with that name.",
                    roomId: room.id,
                    newName: room.name,
                    targetRoomName: room.name
                ))
            }
        }

        return DryRunResult(
            operation: .roomsHomeToHA,
            summary: SyncOperation.roomsHomeToHA.summary(changeCount: changes.count),
            changes: changes
        )
    }

    private func dryRunDevicePlacementHAToHome() async throws -> DryRunResult {
        let home = try selectedHome()
        let entityAreaMap = try await buildEntityAreaMap()
        var changes: [SyncChange] = []
        var plannedRoomCreates = Set<String>()

        for (index, accessory) in home.accessories.enumerated() {
            progress = SyncProgress(title: "Matching Apple Home devices", detail: "Device \(index + 1) of \(home.accessories.count): \(accessory.name)", completed: index, total: home.accessories.count)
            guard let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id),
                  let targetAreaName = entityAreaMap[serial] else { continue }

            let currentRoomName = accessory.roomName
            if currentRoomName.caseInsensitiveCompare(targetAreaName) == .orderedSame { continue }

            let existingRoom = home.room(named: targetAreaName)
            if existingRoom == nil, !plannedRoomCreates.contains(targetAreaName.lowercased()) {
                plannedRoomCreates.insert(targetAreaName.lowercased())
                changes.append(SyncChange(
                    action: .createRoom,
                    title: "Create “\(targetAreaName)” in Apple Home",
                    details: "Needed before devices can be moved into it.",
                    newName: targetAreaName,
                    homeId: home.id,
                    targetRoomName: targetAreaName
                ))
            }

            changes.append(SyncChange(
                action: .moveAccessory,
                title: "Move “\(accessory.name)” in Apple Home",
                details: "Apple Home room \(currentRoomName.isEmpty ? RoomSummary.defaultRoomName : currentRoomName) → \(targetAreaName), to match its Home Assistant area.",
                accessoryId: accessory.id,
                roomId: existingRoom?.id,
                targetRoomName: targetAreaName,
                extraData: ["Home Assistant entity": serial]
            ))
        }

        return DryRunResult(
            operation: .devicePlacementHAToHome,
            summary: SyncOperation.devicePlacementHAToHome.summary(changeCount: changes.count),
            changes: changes
        )
    }

    private func dryRunDevicePlacementHomeToHA() async throws -> DryRunResult {
        let home = try selectedHome()
        let entityAreaMap = try await buildEntityAreaMap()
        var changes: [SyncChange] = []

        for (index, accessory) in home.accessories.enumerated() {
            progress = SyncProgress(title: "Matching Apple Home devices", detail: "Device \(index + 1) of \(home.accessories.count): \(accessory.name)", completed: index, total: home.accessories.count)
            guard let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id) else { continue }

            let roomName = accessory.roomName
            guard roomName != RoomSummary.defaultRoomName, !roomName.isEmpty else { continue }

            let areaName = entityAreaMap[serial] ?? ""
            if roomName.caseInsensitiveCompare(areaName) == .orderedSame { continue }

            changes.append(SyncChange(
                action: .moveAccessory,
                title: "Move “\(accessory.name)” in Home Assistant",
                details: "Home Assistant area \(areaName.isEmpty ? "None" : areaName) → \(roomName), to match its Apple Home room.",
                accessoryId: serial,
                targetRoomName: roomName,
                extraData: ["Home Assistant entity": serial]
            ))
        }

        return DryRunResult(
            operation: .devicePlacementHomeToHA,
            summary: SyncOperation.devicePlacementHomeToHA.summary(changeCount: changes.count),
            changes: changes
        )
    }

    private func dryRunDeviceNamesHAToHome() async throws -> DryRunResult {
        let home = try selectedHome()
        let nameMap = try await buildEntityNameMap()
        var changes: [SyncChange] = []

        for (index, accessory) in home.accessories.enumerated() {
            progress = SyncProgress(title: "Matching Apple Home devices", detail: "Device \(index + 1) of \(home.accessories.count): \(accessory.name)", completed: index, total: home.accessories.count)
            guard let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id),
                  let targetName = nameMap[serial] else { continue }
            if accessory.name == targetName { continue }

            changes.append(SyncChange(
                action: .renameAccessory,
                title: "Rename “\(accessory.name)” in Apple Home",
                details: "Apple Home name \(accessory.name) → \(targetName), taken from Home Assistant.",
                accessoryId: accessory.id,
                newName: targetName,
                extraData: ["Home Assistant entity": serial]
            ))
        }

        return DryRunResult(
            operation: .deviceNamesHAToHome,
            summary: SyncOperation.deviceNamesHAToHome.summary(changeCount: changes.count),
            changes: changes
        )
    }

    private func dryRunDeviceNamesHomeToHA() async throws -> DryRunResult {
        let home = try selectedHome()
        let nameMap = try await buildEntityNameMap()
        var changes: [SyncChange] = []

        for (index, accessory) in home.accessories.enumerated() {
            progress = SyncProgress(title: "Matching Apple Home devices", detail: "Device \(index + 1) of \(home.accessories.count): \(accessory.name)", completed: index, total: home.accessories.count)
            guard let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id),
                  let haName = nameMap[serial] else { continue }
            if accessory.name == haName { continue }

            changes.append(SyncChange(
                action: .renameAccessory,
                title: "Rename “\(haName)” in Home Assistant",
                details: "Home Assistant name \(haName) → \(accessory.name), taken from Apple Home.",
                accessoryId: serial,
                newName: accessory.name,
                extraData: ["Home Assistant entity": serial]
            ))
        }

        return DryRunResult(
            operation: .deviceNamesHomeToHA,
            summary: SyncOperation.deviceNamesHomeToHA.summary(changeCount: changes.count),
            changes: changes
        )
    }

    // MARK: - Home Assistant lookup

    /// Looks up everything Home Assistant knows about one bridged accessory,
    /// matching on the HomeKit serial number (which equals the HA entity ID).
    func homeAssistantMatch(forEntityId entityId: String) async throws -> HomeAssistantMatch? {
        try await ensureConnected()

        async let statesTask = wsClient.getStates()
        async let entitiesTask = wsClient.fetchEntityRegistry()
        async let devicesTask = wsClient.fetchDeviceRegistry()
        async let areasTask = wsClient.fetchAreas()

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

    private func selectedHome() throws -> HomeSummary {
        guard let home = homeKitManager.selectedHome else {
            throw BridgeError.notFound("No Apple Home is available yet. Grant HomeKit access, then pick a home.")
        }
        return home
    }

    private func buildEntityAreaMap() async throws -> [String: String] {
        progress = SyncProgress(title: "Reading Home Assistant areas")
        let areas = try await wsClient.fetchAreas()
        progress = SyncProgress(title: "Reading Home Assistant entities")
        let entities = try await wsClient.fetchEntityRegistry()
        progress = SyncProgress(title: "Reading Home Assistant devices")
        let devices = try await wsClient.fetchDeviceRegistry()

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

    private func buildEntityNameMap() async throws -> [String: String] {
        progress = SyncProgress(title: "Reading Home Assistant names")
        let states = try await wsClient.getStates()
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
