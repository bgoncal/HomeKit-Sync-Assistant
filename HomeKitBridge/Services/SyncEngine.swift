import Foundation
import SwiftUI
import HomeKit

struct DryRunResult: Identifiable {
    let id = UUID()
    let operation: SyncOperation
    let summary: String
    let changes: [SyncChange]
}

enum SyncOperation: String, CaseIterable, Identifiable {
    case roomsHAToHome = "Sync Rooms: HA → Apple Home"
    case roomsHomeToHA = "Sync Rooms: Apple Home → HA"
    case devicePlacementHAToHome = "Sync Placement: HA → Apple Home"
    case devicePlacementHomeToHA = "Sync Placement: Apple Home → HA"
    case deviceNamesHAToHome = "Sync Names: HA → Apple Home"
    case deviceNamesHomeToHA = "Sync Names: Apple Home → HA"

    var id: String { rawValue }
}

enum SyncActionType: String {
    case createRoom
    case renameRoom
    case moveAccessory
    case renameAccessory
    case unsupported
}

struct SyncChange: Identifiable {
    let id = UUID()
    let action: SyncActionType
    let title: String
    let details: String
    let accessoryId: String?
    let roomId: String?
    let newName: String?
    let homeId: String?
    let targetRoomName: String?
    let extraData: [String: String]?

    init(action: SyncActionType, title: String, details: String,
         accessoryId: String? = nil, roomId: String? = nil,
         newName: String? = nil, homeId: String? = nil,
         targetRoomName: String? = nil, extraData: [String: String]? = nil) {
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

struct SyncProgress {
    let title: String
    let detail: String?
    let completed: Int?
    let total: Int?

    var fractionCompleted: Double? {
        guard let completed, let total, total > 0 else { return nil }
        return Double(completed) / Double(total)
    }
}

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
            logStore.add(category: .error, message: "HA WebSocket failed", details: wsClient.connectionError ?? "Unknown")
        }
        return ok
    }

    // MARK: - Dry Run

    func dryRun(_ operation: SyncOperation) async throws -> DryRunResult {
        isBusy = true
        progress = SyncProgress(title: "Preparing dry run", detail: operation.rawValue, completed: nil, total: nil)
        defer {
            isBusy = false
            progress = nil
        }

        if !wsClient.isConnected {
            progress = SyncProgress(title: "Connecting to Home Assistant", detail: "Opening WebSocket connection", completed: nil, total: nil)
            let ok = await wsClient.connect()
            if !ok { throw BridgeError.badRequest(wsClient.connectionError ?? "Cannot connect to HA") }
        }

        progress = SyncProgress(title: "Comparing data", detail: operation.rawValue, completed: nil, total: nil)
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
        progress = SyncProgress(title: "Preparing execution", detail: result.operation.rawValue, completed: nil, total: nil)
        defer {
            isBusy = false
            progress = nil
        }

        if !wsClient.isConnected {
            progress = SyncProgress(title: "Connecting to Home Assistant", detail: "Opening WebSocket connection", completed: nil, total: nil)
            let ok = await wsClient.connect()
            if !ok { throw BridgeError.badRequest(wsClient.connectionError ?? "Cannot connect to HA") }
        }

        logStore.add(category: .sync, message: "Executing \(result.operation.rawValue)", details: "\(result.changes.count) changes")

        var successCount = 0
        var failCount = 0

        for (index, change) in result.changes.enumerated() {
            progress = SyncProgress(
                title: "Executing change \(index + 1) of \(result.changes.count)",
                detail: change.title,
                completed: index,
                total: result.changes.count
            )

            do {
                try await executeChange(change, operation: result.operation)
                successCount += 1
                progress = SyncProgress(
                    title: "Completed change \(index + 1) of \(result.changes.count)",
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

        logStore.add(category: .sync, message: "Done \(result.operation.rawValue)", details: "\(successCount) ok, \(failCount) failed")
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
                let _ = try await wsClient.createArea(name: name)
            }

        case .devicePlacementHAToHome:
            switch change.action {
            case .createRoom:
                guard let homeId = change.homeId, let name = change.newName else { return }
                _ = try await homeKitManager.createRoom(homeId: homeId, name: name)
            case .moveAccessory:
                guard let accessoryId = change.accessoryId, let home = homeKitManager.primaryHome else { return }
                let resolvedRoomId: String?
                if let existing = change.roomId {
                    resolvedRoomId = existing
                } else if let roomName = change.targetRoomName,
                          let room = homeKitManager.room(named: roomName, in: home) {
                    resolvedRoomId = room.uniqueIdentifier.uuidString
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
                let _ = try await wsClient.updateEntity(entityId: entityId, updates: ["area_id": finalAreaId])
            }

        case .deviceNamesHAToHome:
            if change.action == .renameAccessory {
                guard let accessoryId = change.accessoryId, let newName = change.newName else { return }
                try await homeKitManager.renameAccessory(id: accessoryId, newName: newName)
            }

        case .deviceNamesHomeToHA:
            if change.action == .renameAccessory {
                guard let entityId = change.accessoryId, let newName = change.newName else { return }
                let _ = try await wsClient.updateEntity(entityId: entityId, updates: ["name": newName])
            }
        }
    }

    // MARK: - Dry Run Implementations

    private func dryRunRoomsHAToHome() async throws -> DryRunResult {
        guard let home = homeKitManager.primaryHome else {
            throw BridgeError.notFound("No HomeKit home available")
        }
        progress = SyncProgress(title: "Fetching Home Assistant areas", detail: nil, completed: nil, total: nil)
        let areas = try await wsClient.fetchAreas()
        var changes: [SyncChange] = []

        for (index, area) in areas.enumerated() {
            progress = SyncProgress(title: "Comparing areas", detail: "Area \(index + 1) of \(areas.count)", completed: index, total: areas.count)
            guard let name = area["name"] as? String else { continue }
            if homeKitManager.room(named: name, in: home) == nil {
                changes.append(SyncChange(
                    action: .createRoom, title: "Create room",
                    details: "Create Apple Home room: \(name)",
                    newName: name, homeId: home.uniqueIdentifier.uuidString, targetRoomName: name
                ))
            }
        }

        return DryRunResult(operation: .roomsHAToHome, summary: "\(changes.count) rooms to create.", changes: changes)
    }

    private func dryRunRoomsHomeToHA() async throws -> DryRunResult {
        guard let home = homeKitManager.primaryHome else {
            throw BridgeError.notFound("No HomeKit home available")
        }
        progress = SyncProgress(title: "Fetching Home Assistant areas", detail: nil, completed: nil, total: nil)
        let areas = try await wsClient.fetchAreas()
        let areaNames = Set(areas.compactMap { ($0["name"] as? String)?.lowercased() })

        let rooms = home.rooms.filter { $0.name != "Default Room" }
        var changes: [SyncChange] = []
        for (index, room) in rooms.enumerated() {
            progress = SyncProgress(title: "Comparing HomeKit rooms", detail: "Room \(index + 1) of \(rooms.count)", completed: index, total: rooms.count)
            if !areaNames.contains(room.name.lowercased()) {
                changes.append(SyncChange(
                    action: .createRoom, title: "Create HA area",
                    details: "Create area in HA: \(room.name)",
                    roomId: room.uniqueIdentifier.uuidString, newName: room.name, targetRoomName: room.name
                ))
            }
        }

        return DryRunResult(operation: .roomsHomeToHA, summary: "\(changes.count) rooms to create in HA.", changes: changes)
    }

    private func dryRunDevicePlacementHAToHome() async throws -> DryRunResult {
        guard let home = homeKitManager.primaryHome else {
            throw BridgeError.notFound("No HomeKit home available")
        }

        let entityAreaMap = try await buildEntityAreaMap()
        var changes: [SyncChange] = []
        var plannedRoomCreates = Set<String>()

        for (index, accessory) in home.accessories.enumerated() {
            progress = SyncProgress(title: "Reading HomeKit accessories", detail: "Accessory \(index + 1) of \(home.accessories.count): \(accessory.name)", completed: index, total: home.accessories.count)
            let serial = await homeKitManager.readSerialNumber(for: accessory)
            guard !serial.isEmpty, let targetAreaName = entityAreaMap[serial] else { continue }

            let currentRoomName = accessory.room?.name ?? ""
            if currentRoomName.caseInsensitiveCompare(targetAreaName) == .orderedSame { continue }

            let existingRoom = homeKitManager.room(named: targetAreaName, in: home)
            if existingRoom == nil, !plannedRoomCreates.contains(targetAreaName.lowercased()) {
                plannedRoomCreates.insert(targetAreaName.lowercased())
                changes.append(SyncChange(
                    action: .createRoom, title: "Create missing room",
                    details: "Create Apple Home room: \(targetAreaName)",
                    newName: targetAreaName, homeId: home.uniqueIdentifier.uuidString, targetRoomName: targetAreaName
                ))
            }

            changes.append(SyncChange(
                action: .moveAccessory, title: "Move \(accessory.name)",
                details: "\(currentRoomName.isEmpty ? "Unassigned" : currentRoomName) → \(targetAreaName)",
                accessoryId: accessory.uniqueIdentifier.uuidString,
                roomId: existingRoom?.uniqueIdentifier.uuidString, targetRoomName: targetAreaName
            ))
        }

        return DryRunResult(operation: .devicePlacementHAToHome, summary: "\(changes.count) placement changes.", changes: changes)
    }

    private func dryRunDevicePlacementHomeToHA() async throws -> DryRunResult {
        guard let home = homeKitManager.primaryHome else {
            throw BridgeError.notFound("No HomeKit home available")
        }

        let entityAreaMap = try await buildEntityAreaMap()
        var changes: [SyncChange] = []

        for (index, accessory) in home.accessories.enumerated() {
            progress = SyncProgress(title: "Reading HomeKit accessories", detail: "Accessory \(index + 1) of \(home.accessories.count): \(accessory.name)", completed: index, total: home.accessories.count)
            let serial = await homeKitManager.readSerialNumber(for: accessory)
            guard !serial.isEmpty else { continue }

            let hkRoomName = accessory.room?.name ?? ""
            guard hkRoomName != "Default Room", !hkRoomName.isEmpty else { continue }

            let haAreaName = entityAreaMap[serial] ?? ""
            if hkRoomName.caseInsensitiveCompare(haAreaName) == .orderedSame { continue }

            changes.append(SyncChange(
                action: .moveAccessory, title: "Move \(accessory.name) in HA",
                details: "\(haAreaName.isEmpty ? "No area" : haAreaName) → \(hkRoomName)",
                accessoryId: serial, targetRoomName: hkRoomName
            ))
        }

        return DryRunResult(operation: .devicePlacementHomeToHA, summary: "\(changes.count) devices to re-assign in HA.", changes: changes)
    }

    private func dryRunDeviceNamesHAToHome() async throws -> DryRunResult {
        guard let home = homeKitManager.primaryHome else {
            throw BridgeError.notFound("No HomeKit home available")
        }

        let nameMap = try await buildEntityNameMap()
        var changes: [SyncChange] = []

        for (index, accessory) in home.accessories.enumerated() {
            progress = SyncProgress(title: "Reading HomeKit accessories", detail: "Accessory \(index + 1) of \(home.accessories.count): \(accessory.name)", completed: index, total: home.accessories.count)
            let serial = await homeKitManager.readSerialNumber(for: accessory)
            guard !serial.isEmpty, let targetName = nameMap[serial] else { continue }
            if accessory.name == targetName { continue }

            changes.append(SyncChange(
                action: .renameAccessory, title: "Rename accessory",
                details: "\(accessory.name) → \(targetName)",
                accessoryId: accessory.uniqueIdentifier.uuidString, newName: targetName
            ))
        }

        return DryRunResult(operation: .deviceNamesHAToHome, summary: "\(changes.count) name updates.", changes: changes)
    }

    private func dryRunDeviceNamesHomeToHA() async throws -> DryRunResult {
        guard let home = homeKitManager.primaryHome else {
            throw BridgeError.notFound("No HomeKit home available")
        }

        let nameMap = try await buildEntityNameMap()
        var changes: [SyncChange] = []

        for (index, accessory) in home.accessories.enumerated() {
            progress = SyncProgress(title: "Reading HomeKit accessories", detail: "Accessory \(index + 1) of \(home.accessories.count): \(accessory.name)", completed: index, total: home.accessories.count)
            let serial = await homeKitManager.readSerialNumber(for: accessory)
            guard !serial.isEmpty, let haName = nameMap[serial] else { continue }

            let hkName = accessory.name
            if hkName == haName { continue }

            changes.append(SyncChange(
                action: .renameAccessory, title: "Rename entity in HA",
                details: "\(haName) → \(hkName)",
                accessoryId: serial, newName: hkName
            ))
        }

        return DryRunResult(operation: .deviceNamesHomeToHA, summary: "\(changes.count) name updates in HA.", changes: changes)
    }

    // MARK: - Helpers

    private func buildEntityAreaMap() async throws -> [String: String] {
        progress = SyncProgress(title: "Fetching Home Assistant areas", detail: nil, completed: nil, total: nil)
        let areas = try await wsClient.fetchAreas()
        progress = SyncProgress(title: "Fetching Home Assistant entities", detail: nil, completed: nil, total: nil)
        let entities = try await wsClient.fetchEntityRegistry()
        progress = SyncProgress(title: "Fetching Home Assistant devices", detail: nil, completed: nil, total: nil)
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
        progress = SyncProgress(title: "Fetching Home Assistant states", detail: nil, completed: nil, total: nil)
        let states = try await wsClient.getStates()
        var result: [String: String] = [:]
        for (index, state) in states.enumerated() {
            progress = SyncProgress(title: "Reading Home Assistant names", detail: "Entity \(index + 1) of \(states.count)", completed: index, total: states.count)
            if let entityId = state["entity_id"] as? String,
               let attrs = state["attributes"] as? [String: Any],
               let friendlyName = attrs["friendly_name"] as? String {
                result[entityId] = friendlyName
            }
        }
        return result
    }
}
