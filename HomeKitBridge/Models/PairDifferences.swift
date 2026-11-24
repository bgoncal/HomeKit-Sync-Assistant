import Foundation

/// One device whose two sides disagree about something.
struct DeviceDifference: Identifiable, Equatable {
    let id: String
    let deviceName: String
    let appleHomeValue: String
    let homeAssistantValue: String
}

/// How one Apple Home and one Home Assistant compare, before any sync is chosen.
struct PairDifferences: Equatable {
    let homeName: String
    let serverName: String
    /// Rooms with no area of the same name.
    var roomsOnlyInAppleHome: [String] = []
    /// Areas with no room of the same name.
    var areasOnlyInHomeAssistant: [String] = []
    var differentRoom: [DeviceDifference] = []
    var differentName: [DeviceDifference] = []
    /// Devices with no entity to compare with: not bridged, or the entity is gone.
    var unmatchedDevices: [String] = []
    /// Matched devices whose room and name already agree.
    var matchingCount: Int = 0

    var isEverythingInSync: Bool {
        roomsOnlyInAppleHome.isEmpty && areasOnlyInHomeAssistant.isEmpty
            && differentRoom.isEmpty && differentName.isEmpty
    }
}
