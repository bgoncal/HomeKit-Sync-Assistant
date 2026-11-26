import Foundation

/// Manual pairings and exclusions, kept in `UserDefaults` and mirrored to iCloud.
///
/// Every mutation stamps the entry with the current time and goes through here, so
/// `SyncPreferencesPayload.merged` can reconcile two devices without a server.
@MainActor
final class SyncPreferencesStore: ObservableObject {
    @Published private(set) var payload = SyncPreferencesPayload()
    /// False when iCloud is off or signed out: exclusions and pairings then stay on
    /// this device, and the screens that set them say so.
    @Published private(set) var isSyncingWithCloud = false

    static let defaultsKey = "syncPreferences"
    /// Where a stored payload that could not be read is kept, rather than lost.
    static let undecodableKey = "syncPreferences.undecodable"

    private let defaults: UserDefaults
    private let cloud: ConfigurationSyncStore?
    private let now: () -> Date
    private var identityObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard, cloud: ConfigurationSyncStore? = nil, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.cloud = cloud
        self.now = now

        if let data = defaults.data(forKey: Self.defaultsKey) {
            if let stored = try? JSONDecoder().decode(SyncPreferencesPayload.self, from: data) {
                payload = stored
            } else {
                defaults.set(data, forKey: Self.undecodableKey)
            }
        }
        isSyncingWithCloud = cloud?.isAvailable ?? false
        mergeFromCloud()

        cloud?.onExternalChange = { [weak self] in
            self?.mergeFromCloud()
        }
        cloud?.startObserving()

        identityObserver = NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isSyncingWithCloud = self.cloud?.isAvailable ?? false
                self.mergeFromCloud()
            }
        }
    }

    // MARK: - Reading

    /// The entity chosen by hand for an accessory against this server, if any.
    func manualEntityId(forAccessoryId accessoryId: String, serverId: UUID) -> String? {
        guard let value = payload.manualPairings[accessoryId]?.value else { return nil }
        let prefix = "\(serverId.uuidString)|"
        return value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : nil
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

    /// Every live room exclusion, as (homeId, lowercased name, name as typed).
    var excludedRooms: [(homeId: String, key: String, name: String)] {
        payload.excludedRooms.compactMap { key, entry in
            guard let name = entry.value, let separator = key.firstIndex(of: "|") else { return nil }
            return (String(key[..<separator]), String(key[key.index(after: separator)...]), name)
        }
    }

    /// Every live exclusion, including ones whose device or home is gone.
    var exclusionCount: Int {
        payload.excludedAccessories.values.filter { $0.value != nil }.count
            + payload.excludedRooms.values.filter { $0.value != nil }.count
    }

    // MARK: - Changing

    func setManualEntityId(_ entityId: String?, serverId: UUID, forAccessoryId accessoryId: String) {
        let value = entityId.map { SyncPreferencesPayload.pairingValue(serverId: serverId, entityId: $0) }
        payload.manualPairings[accessoryId] = PreferenceEntry(value: value, updatedAt: now())
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

    /// Moves hand-made pairings from servers folded into another one onto the server
    /// that was kept. They are the same Home Assistant, so the entity IDs still hold.
    func moveManualPairings(from folded: [UUID: UUID]) {
        guard !folded.isEmpty else { return }
        var changed = false
        for (accessoryId, entry) in payload.manualPairings {
            guard let value = entry.value, let separator = value.firstIndex(of: "|"),
                  let serverId = UUID(uuidString: String(value[..<separator])),
                  let kept = folded[serverId] else { continue }
            let entityId = String(value[value.index(after: separator)...])
            payload.manualPairings[accessoryId] = PreferenceEntry(
                value: SyncPreferencesPayload.pairingValue(serverId: kept, entityId: entityId),
                updatedAt: now()
            )
            changed = true
        }
        if changed { save() }
    }

    // MARK: - Persistence

    private func save() {
        // Fold in what other devices wrote first, so this write cannot drop it.
        if let remote = remotePayload() {
            payload = SyncPreferencesPayload.merged(payload, remote)
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
        cloud?.set(data, forKey: Self.defaultsKey)
    }

    private func remotePayload() -> SyncPreferencesPayload? {
        guard let data = cloud?.data(forKey: Self.defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SyncPreferencesPayload.self, from: data)
    }

    /// Merges iCloud's copy in, and writes the result back whenever iCloud's copy is
    /// missing, unreadable or behind — so a device that has choices always shares them.
    private func mergeFromCloud() {
        guard let cloud else { return }
        let remote = remotePayload()
        let merged = remote.map { SyncPreferencesPayload.merged(payload, $0) } ?? payload

        if merged != payload {
            payload = merged
            if let data = try? JSONEncoder().encode(merged) {
                defaults.set(data, forKey: Self.defaultsKey)
            }
        }
        if merged != remote, merged != SyncPreferencesPayload() || remote != nil,
           let data = try? JSONEncoder().encode(merged) {
            cloud.set(data, forKey: Self.defaultsKey)
        }
    }
}
