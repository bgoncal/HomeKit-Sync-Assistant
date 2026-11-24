import Foundation

/// Manual pairings and exclusions, kept in `UserDefaults` and mirrored to iCloud.
///
/// Every mutation stamps the entry with the current time and goes through here, so
/// `SyncPreferencesPayload.merged` can reconcile two devices without a server.
@MainActor
final class SyncPreferencesStore: ObservableObject {
    @Published private(set) var payload = SyncPreferencesPayload()

    static let defaultsKey = "syncPreferences"

    private let defaults: UserDefaults
    private let cloud: ConfigurationSyncStore?
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, cloud: ConfigurationSyncStore? = nil, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.cloud = cloud
        self.now = now

        if let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode(SyncPreferencesPayload.self, from: data) {
            payload = stored
        }
        mergeFromCloud()

        cloud?.onExternalChange = { [weak self] in
            self?.mergeFromCloud()
        }
        cloud?.startObserving()
    }

    // MARK: - Reading

    /// The entity chosen by hand for an accessory, if any.
    func manualEntityId(forAccessoryId accessoryId: String) -> String? {
        payload.manualPairings[accessoryId]?.value
    }

    func isAccessoryExcluded(_ accessoryId: String) -> Bool {
        payload.excludedAccessories[accessoryId]?.value != nil
    }

    func isRoomExcluded(homeId: String, roomName: String) -> Bool {
        payload.excludedRooms[SyncPreferencesPayload.roomKey(homeId: homeId, roomName: roomName)]?.value != nil
    }

    /// True when a sync must leave this accessory alone, on its own or by its room.
    func isExcluded(_ accessory: AccessorySummary, homeId: String) -> Bool {
        isAccessoryExcluded(accessory.id) || isRoomExcluded(homeId: homeId, roomName: accessory.roomName)
    }

    var excludedAccessoryIds: Set<String> {
        Set(payload.excludedAccessories.compactMap { $0.value.value == nil ? nil : $0.key })
    }

    /// Lowercased names of the excluded rooms in one home.
    func excludedRoomNames(homeId: String) -> Set<String> {
        let prefix = "\(homeId)|"
        return Set(payload.excludedRooms.compactMap { key, entry in
            entry.value == nil || !key.hasPrefix(prefix) ? nil : String(key.dropFirst(prefix.count))
        })
    }

    /// Every live exclusion, for the screen that lists them.
    var exclusionCount: Int {
        payload.excludedAccessories.values.filter { $0.value != nil }.count
            + payload.excludedRooms.values.filter { $0.value != nil }.count
    }

    // MARK: - Changing

    func setManualEntityId(_ entityId: String?, forAccessoryId accessoryId: String) {
        payload.manualPairings[accessoryId] = PreferenceEntry(value: entityId, updatedAt: now())
        save()
    }

    func setAccessoryExcluded(_ excluded: Bool, accessoryId: String) {
        payload.excludedAccessories[accessoryId] = PreferenceEntry(value: excluded ? "1" : nil, updatedAt: now())
        save()
    }

    func setRoomExcluded(_ excluded: Bool, homeId: String, roomName: String) {
        payload.excludedRooms[SyncPreferencesPayload.roomKey(homeId: homeId, roomName: roomName)] =
            PreferenceEntry(value: excluded ? roomName : nil, updatedAt: now())
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
        cloud?.set(data, forKey: Self.defaultsKey)
    }

    private func mergeFromCloud() {
        guard let data = cloud?.data(forKey: Self.defaultsKey),
              let remote = try? JSONDecoder().decode(SyncPreferencesPayload.self, from: data) else { return }
        let merged = SyncPreferencesPayload.merged(payload, remote)
        guard merged != payload || merged != remote else { return }
        payload = merged
        if let mergedData = try? JSONEncoder().encode(merged) {
            defaults.set(mergedData, forKey: Self.defaultsKey)
            if merged != remote {
                cloud?.set(mergedData, forKey: Self.defaultsKey)
            }
        }
    }
}
