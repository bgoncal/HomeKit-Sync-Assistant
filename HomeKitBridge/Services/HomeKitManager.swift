import Foundation
import HomeKit

@MainActor
final class HomeKitManager: NSObject, ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var homes: [HMHome] = []
    @Published private(set) var selectedHomeId: String?

    private static let selectedHomeDefaultsKey = "selectedHomeId"
    private var manager: HMHomeManager?

    var primaryHome: HMHome? {
        if let selectedHomeId, let selectedHome = home(byId: selectedHomeId) {
            return selectedHome
        }
        return homes.first
    }

    override init() {
        selectedHomeId = UserDefaults.standard.string(forKey: Self.selectedHomeDefaultsKey)
        super.init()
        requestAccess()
    }

    func requestAccess() {
        if manager == nil {
            let m = HMHomeManager()
            m.delegate = self
            manager = m
        }
    }

    func home(byId id: String) -> HMHome? {
        homes.first { $0.uniqueIdentifier.uuidString == id }
    }

    func selectHome(id: String) {
        guard homes.contains(where: { $0.uniqueIdentifier.uuidString == id }) else { return }
        selectedHomeId = id
        UserDefaults.standard.set(id, forKey: Self.selectedHomeDefaultsKey)
    }

    private func updateHomes(_ newHomes: [HMHome]) {
        homes = newHomes

        if let selectedHomeId, newHomes.contains(where: { $0.uniqueIdentifier.uuidString == selectedHomeId }) {
            return
        }

        selectedHomeId = newHomes.first?.uniqueIdentifier.uuidString
        if let selectedHomeId {
            UserDefaults.standard.set(selectedHomeId, forKey: Self.selectedHomeDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedHomeDefaultsKey)
        }
    }

    func accessory(byId id: String) -> HMAccessory? {
        for home in homes {
            if let accessory = home.accessories.first(where: { $0.uniqueIdentifier.uuidString == id }) {
                return accessory
            }
        }
        return nil
    }

    func room(named name: String, in home: HMHome) -> HMRoom? {
        home.rooms.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func readSerialNumber(for accessory: HMAccessory) async -> String {
        guard let infoService = accessory.services.first(where: { $0.serviceType == HMServiceTypeAccessoryInformation }),
              let serialChar = infoService.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeSerialNumber }) else {
            return ""
        }

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                serialChar.readValue { error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
            return serialChar.value as? String ?? ""
        } catch {
            return serialChar.value as? String ?? ""
        }
    }

    func accessoriesWithSerial(forHomeId homeId: String) async -> [[String: Any]]? {
        guard let home = home(byId: homeId) else { return nil }

        var result: [[String: Any]] = []
        for accessory in home.accessories {
            let serial = await readSerialNumber(for: accessory)
            result.append([
                "id": accessory.uniqueIdentifier.uuidString,
                "name": accessory.name,
                "room": accessory.room?.name ?? "Default Room",
                "serialNumber": serial,
                "manufacturer": accessory.manufacturer,
                "model": accessory.model
            ])
        }
        return result
    }

    func createRoom(homeId: String, name: String) async throws -> HMRoom {
        guard let home = home(byId: homeId) else {
            throw BridgeError.notFound("Home not found")
        }

        return try await withCheckedThrowingContinuation { cont in
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
    }

    func renameRoom(id: String, newName: String) async throws {
        guard let room = homes
            .flatMap({ $0.rooms })
            .first(where: { $0.uniqueIdentifier.uuidString == id }) else {
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
    }

    func moveAccessory(id: String, toRoomId roomId: String) async throws {
        guard let accessory = accessory(byId: id) else {
            throw BridgeError.notFound("Accessory not found")
        }

        guard let home = homes.first(where: { $0.accessories.contains(where: { $0.uniqueIdentifier == accessory.uniqueIdentifier }) }) else {
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
    }

    func renameAccessory(id: String, newName: String) async throws {
        guard let accessory = accessory(byId: id) else {
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
