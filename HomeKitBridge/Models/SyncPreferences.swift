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
    /// Accessory ID → entity ID.
    var manualPairings: [String: PreferenceEntry] = [:]
    /// Accessory ID → "1" while excluded.
    var excludedAccessories: [String: PreferenceEntry] = [:]
    /// `SyncPreferencesPayload.roomKey(homeId:roomName:)` → the room's name while excluded.
    var excludedRooms: [String: PreferenceEntry] = [:]

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
            // Same instant on two devices: pick by value so both sides agree.
            return (mine.value ?? "") >= (theirs.value ?? "") ? mine : theirs
        }
    }
}
