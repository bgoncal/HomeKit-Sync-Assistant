import Foundation
import HomeKit

@MainActor
final class HomeKitManager: NSObject, ObservableObject {
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var homes: [HomeSummary] = []
    @Published private(set) var selectedHomeId: String?

    private static let selectedHomeDefaultsKey = "selectedHomeId"
    private var manager: HMHomeManager?
    /// Serial numbers are read on demand from the accessory and cached, because
    /// every Home Assistant match keys off them.
    private var serialNumbers: [String: String] = [:]

    /// The home every screen and sync operation works against.
    var selectedHome: HomeSummary? {
        if let selectedHomeId, let home = home(byId: selectedHomeId) {
            return home
        }
        return homes.first
    }

    override init() {
        selectedHomeId = UserDefaults.standard.string(forKey: Self.selectedHomeDefaultsKey)
        super.init()
        requestAccess()
    }

    func requestAccess() {
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        if manager == nil {
            let manager = HMHomeManager()
            manager.delegate = self
            self.manager = manager
        }
    }

    // MARK: - Lookup

    func home(byId id: String) -> HomeSummary? {
        homes.first { $0.id == id }
    }

    func accessory(byId id: String) -> AccessorySummary? {
        for home in homes {
            if let accessory = home.accessory(id: id) { return accessory }
        }
        return nil
    }

    func room(named name: String, inHomeId homeId: String) -> RoomSummary? {
        home(byId: homeId)?.room(named: name)
    }

    func selectHome(id: String) {
        guard homes.contains(where: { $0.id == id }) else { return }
        selectedHomeId = id
        UserDefaults.standard.set(id, forKey: Self.selectedHomeDefaultsKey)
    }

    // MARK: - Serial numbers

    /// Reads the serial number from an accessory, caching it and republishing the
    /// affected summary. Returns `nil` when the accessory exposes no serial number.
    @discardableResult
    func refreshSerialNumber(accessoryId: String) async -> String? {
        guard let accessory = hkAccessory(byId: accessoryId) else { return nil }
        let serial = await readSerialNumber(from: accessory)

        guard !serial.isEmpty else { return nil }
        serialNumbers[accessoryId] = serial
        applyCachedSerialNumbers()
        return serial
    }

    /// Reads every serial number in a home, so accessories can be matched against
    /// Home Assistant entity IDs.
    func refreshSerialNumbers(forHomeId homeId: String) async {
        guard let home = hkHome(byId: homeId) else { return }
        for accessory in home.accessories {
            let serial = await readSerialNumber(from: accessory)
            guard !serial.isEmpty else { continue }
            serialNumbers[accessory.uniqueIdentifier.uuidString] = serial
        }
        applyCachedSerialNumbers()
    }

    func accessoriesWithSerials(forHomeId homeId: String) async -> [AccessorySummary]? {
        guard home(byId: homeId) != nil else { return nil }
        await refreshSerialNumbers(forHomeId: homeId)
        return home(byId: homeId)?.accessories
    }

    private func readSerialNumber(from accessory: HMAccessory) async -> String {
        guard let infoService = accessory.services.first(where: { $0.serviceType == HMServiceTypeAccessoryInformation }),
              let serialCharacteristic = infoService.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeSerialNumber }) else {
            return ""
        }

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                serialCharacteristic.readValue { error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
            return serialCharacteristic.value as? String ?? ""
        } catch {
            return serialCharacteristic.value as? String ?? ""
        }
    }

    // MARK: - Mutations

    @discardableResult
    func createRoom(homeId: String, name: String) async throws -> RoomSummary {
        guard let home = hkHome(byId: homeId) else {
            throw BridgeError.notFound("Home not found")
        }

        let room: HMRoom = try await withCheckedThrowingContinuation { cont in
            home.addRoom(withName: name) { room, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let room {
                    cont.resume(returning: room)
                } else {
                    cont.resume(throwing: BridgeError.badRequest("Could not create room"))
                }
            }
        }

        refreshHomes()
        return RoomSummary(id: room.uniqueIdentifier.uuidString, name: room.name)
    }

    func renameRoom(id: String, newName: String) async throws {
        guard let room = hkRoom(byId: id) else {
            throw BridgeError.notFound("Room not found")
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            room.updateName(newName) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }

        refreshHomes()
    }

    func moveAccessory(id: String, toRoomId roomId: String) async throws {
        guard let accessory = hkAccessory(byId: id) else {
            throw BridgeError.notFound("Accessory not found")
        }

        guard let home = hkHome(containingAccessoryId: id) else {
            throw BridgeError.notFound("Accessory home not found")
        }

        guard let room = home.rooms.first(where: { $0.uniqueIdentifier.uuidString == roomId }) else {
            throw BridgeError.notFound("Room not found")
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            home.assignAccessory(accessory, to: room) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }

        refreshHomes()
    }

    func renameAccessory(id: String, newName: String) async throws {
        guard let accessory = hkAccessory(byId: id) else {
            throw BridgeError.notFound("Accessory not found")
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            accessory.updateName(newName) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }

        refreshHomes()
    }

    // MARK: - HomeKit objects

    private func hkHome(byId id: String) -> HMHome? {
        manager?.homes.first { $0.uniqueIdentifier.uuidString == id }
    }

    private func hkHome(containingAccessoryId id: String) -> HMHome? {
        manager?.homes.first { home in
            home.accessories.contains { $0.uniqueIdentifier.uuidString == id }
        }
    }

    private func hkAccessory(byId id: String) -> HMAccessory? {
        manager?.homes
            .flatMap(\.accessories)
            .first { $0.uniqueIdentifier.uuidString == id }
    }

    private func hkRoom(byId id: String) -> HMRoom? {
        manager?.homes
            .flatMap(\.rooms)
            .first { $0.uniqueIdentifier.uuidString == id }
    }

    // MARK: - Summaries

    private func refreshHomes() {
        updateHomes(manager?.homes ?? [])
    }

    private func updateHomes(_ newHomes: [HMHome]) {
        homes = newHomes.map(Self.summary(for:))
        applyCachedSerialNumbers()

        if let selectedHomeId, homes.contains(where: { $0.id == selectedHomeId }) {
            return
        }

        selectedHomeId = homes.first?.id
        if let selectedHomeId {
            UserDefaults.standard.set(selectedHomeId, forKey: Self.selectedHomeDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedHomeDefaultsKey)
        }
    }

    private func applyCachedSerialNumbers() {
        guard !serialNumbers.isEmpty else { return }
        for homeIndex in homes.indices {
            for accessoryIndex in homes[homeIndex].accessories.indices {
                let id = homes[homeIndex].accessories[accessoryIndex].id
                if let serial = serialNumbers[id] {
                    homes[homeIndex].accessories[accessoryIndex].serialNumber = serial
                }
            }
        }
    }

    private static func summary(for home: HMHome) -> HomeSummary {
        HomeSummary(
            id: home.uniqueIdentifier.uuidString,
            name: home.name,
            rooms: home.rooms.map { RoomSummary(id: $0.uniqueIdentifier.uuidString, name: $0.name) },
            accessories: home.accessories.map(summary(for:))
        )
    }

    private static func summary(for accessory: HMAccessory) -> AccessorySummary {
        AccessorySummary(
            id: accessory.uniqueIdentifier.uuidString,
            name: accessory.name,
            roomId: accessory.room?.uniqueIdentifier.uuidString,
            roomName: accessory.room?.name ?? RoomSummary.defaultRoomName,
            manufacturer: accessory.manufacturer,
            model: accessory.model,
            category: accessory.category.localizedDescription,
            isReachable: accessory.isReachable,
            isBlocked: accessory.isBlocked,
            isBridged: accessory.isBridged,
            services: accessory.services.map { service in
                ServiceSummary(
                    id: service.uniqueIdentifier.uuidString,
                    name: service.name,
                    type: service.serviceType,
                    characteristics: service.characteristics.map { characteristic in
                        CharacteristicSummary(
                            id: characteristic.uniqueIdentifier.uuidString,
                            type: characteristic.characteristicType,
                            value: describe(characteristic.value)
                        )
                    }
                )
            }
        )
    }

    private static func describe(_ value: Any?) -> String {
        guard let value else { return "Unavailable" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }
}

extension HomeKitManager: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.updateHomes(manager.homes)
            self.isAuthorized = true
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        Task { @MainActor in
            self.updateHomes(manager.homes)
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        Task { @MainActor in
            self.updateHomes(manager.homes)
        }
    }
}
