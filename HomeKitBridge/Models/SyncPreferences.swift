import Foundation

/// One remembered choice and when it was made. A `nil` value is a removal, kept as
/// a tombstone so an older device coming back cannot quietly restore it.
struct PreferenceEntry: Codable, Equatable {
    var value: String?
    var updatedAt: Date
}

/// The per-device choices that change what a sync touches, shared between the
/// person's devices through iCloud's key-value store:
///
/// - **Manual pairings**: an Apple Home accessory matched by hand to a Home Assistant
///   entity, for devices whose serial number does not carry the entity ID.
/// - **Exclusions**: accessories and rooms every sync leaves alone.
///
/// Keys and values are identifiers only — never a token, never an address.
struct SyncPreferencesPayload: Codable, Equatable {
    /// Accessory ID → "serverId|entityId": a pairing is made against one server's list.
    var manualPairings: [String: PreferenceEntry] = [:]
    /// Accessory ID → "1" while excluded.
    var excludedAccessories: [String: PreferenceEntry] = [:]
    /// `SyncPreferencesPayload.roomKey(homeId:roomName:)` → the room's name while excluded.
    var excludedRooms: [String: PreferenceEntry] = [:]

    init(
        manualPairings: [String: PreferenceEntry] = [:],
        excludedAccessories: [String: PreferenceEntry] = [:],
        excludedRooms: [String: PreferenceEntry] = [:]
    ) {
        self.manualPairings = manualPairings
        self.excludedAccessories = excludedAccessories
        self.excludedRooms = excludedRooms
    }

    /// Every map is optional when decoding, so a later version can add one without
    /// an older payload failing to decode — which would read as "nothing excluded".
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manualPairings = try container.decodeIfPresent([String: PreferenceEntry].self, forKey: .manualPairings) ?? [:]
        excludedAccessories = try container.decodeIfPresent([String: PreferenceEntry].self, forKey: .excludedAccessories) ?? [:]
        excludedRooms = try container.decodeIfPresent([String: PreferenceEntry].self, forKey: .excludedRooms) ?? [:]
    }

    static func pairingValue(serverId: UUID, entityId: String) -> String {
        "\(serverId.uuidString)|\(entityId)"
    }

    static func roomKey(homeId: String, roomName: String) -> String {
        "\(homeId)|\(roomName.lowercased())"
    }

    /// Newest entry wins per key, tombstones included. Pure, commutative and
    /// idempotent, so the order two devices merge in never matters.
    static func merged(_ local: SyncPreferencesPayload, _ remote: SyncPreferencesPayload) -> SyncPreferencesPayload {
        SyncPreferencesPayload(
            manualPairings: merge(local.manualPairings, remote.manualPairings),
            excludedAccessories: merge(local.excludedAccessories, remote.excludedAccessories),
            excludedRooms: merge(local.excludedRooms, remote.excludedRooms)
        )
    }

    private static func merge(_ left: [String: PreferenceEntry], _ right: [String: PreferenceEntry]) -> [String: PreferenceEntry] {
        left.merging(right) { mine, theirs in
            if mine.updatedAt != theirs.updatedAt {
                return mine.updatedAt > theirs.updatedAt ? mine : theirs
            }
            // Same instant on two devices: pick by value so both sides agree. A removal
            // sorts below every value, so `nil` and "" never tie.
            let left = (mine.value == nil ? 0 : 1, mine.value ?? "")
            let right = (theirs.value == nil ? 0 : 1, theirs.value ?? "")
            return left >= right ? mine : theirs
        }
    }
}
