import SwiftUI

/// One device or room every sync leaves alone.
struct ExclusionItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case device(accessoryId: String)
        case room(homeId: String, roomName: String)
    }

    let id: String
    let kind: Kind
    let title: String
    /// The home it belongs to.
    let subtitle: String
}

/// Everything left out of syncs, gathered in one place so it is easy to undo.
struct ExclusionsView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var preferences: SyncPreferencesStore

    var body: some View {
        ExclusionsContent(items: items, isSyncingWithCloud: preferences.isSyncingWithCloud) { item in
            switch item.kind {
            case .device(let accessoryId):
                preferences.setAccessoryExcluded(false, accessoryId: accessoryId)
            case .room(let homeId, let roomName):
                preferences.setRoomExcluded(false, homeId: homeId, roomName: roomName)
            }
        }
    }

    /// Every live exclusion, including ones whose device, room or home is gone, so
    /// the list always matches the count on Home and leftovers can be cleared.
    private var items: [ExclusionItem] {
        var result: [ExclusionItem] = []
        let homesById = Dictionary(homeKitManager.homes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for room in preferences.excludedRooms.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending }) {
            let home = homesById[room.homeId]
            let subtitle: String
            if let home {
                subtitle = home.room(named: room.name) == nil ? "\(home.name) · No room with this name now" : home.name
            } else {
                subtitle = "Home no longer available"
            }
            result.append(ExclusionItem(
                id: "room|\(room.homeId)|\(room.key)",
                kind: .room(homeId: room.homeId, roomName: room.name),
                title: room.name,
                subtitle: subtitle
            ))
        }

        let accessories = homeKitManager.homes.flatMap { home in home.accessories.map { (home, $0) } }
        for accessoryId in preferences.excludedAccessoryIds.sorted() {
            if let (home, accessory) = accessories.first(where: { $0.1.id == accessoryId }) {
                result.append(ExclusionItem(
                    id: "device|\(accessoryId)",
                    kind: .device(accessoryId: accessoryId),
                    title: accessory.name,
                    subtitle: "\(home.name) · \(accessory.roomName)"
                ))
            } else {
                result.append(ExclusionItem(
                    id: "device|\(accessoryId)",
                    kind: .device(accessoryId: accessoryId),
                    title: "Removed Device",
                    subtitle: "No longer in Apple Home"
                ))
            }
        }
        return result
    }
}

struct ExclusionsContent: View {
    let items: [ExclusionItem]
    var isSyncingWithCloud: Bool = true
    var onInclude: (ExclusionItem) -> Void = { _ in }

    private var rooms: [ExclusionItem] {
        items.filter { if case .room = $0.kind { return true } else { return false } }
    }

    private var devices: [ExclusionItem] {
        items.filter { if case .device = $0.kind { return true } else { return false } }
    }

    var body: some View {
        List {
            if !rooms.isEmpty {
                Section {
                    ForEach(rooms) { row($0, systemImage: "square.split.bottomrightquarter") }
                } header: {
                    Text("Rooms")
                } footer: {
                    Text("Nothing in these rooms is renamed or moved, and no area is created for them.")
                }
            }

            if !devices.isEmpty {
                Section {
                    ForEach(devices) { row($0, systemImage: "sensor") }
                } header: {
                    Text("Devices")
                } footer: {
                    Text("These keep their name and room on both sides, whatever a sync would change.")
                }
            }

            if !items.isEmpty {
                Section {
                } footer: {
                    Text(isSyncingWithCloud
                         ? "Exclusions are shared through iCloud, so your other devices leave these alone too."
                         : "iCloud is off, so these exclusions are only on this device. A sync on another device will still change them.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(
                    "Nothing Excluded",
                    systemImage: "minus.circle",
                    description: Text("Press and hold a device or room in an Apple Home's device list to leave it out of every sync.")
                )
            }
        }
        .navigationTitle("Excluded from Syncs")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ item: ExclusionItem, systemImage: String) -> some View {
        Label {
            Text(item.title)
            Text(item.subtitle)
        } icon: {
            Image(systemName: systemImage)
        }
        .swipeActions(edge: .trailing) {
            Button("Include", systemImage: "plus.circle") { onInclude(item) }
                .tint(.green)
        }
        .contextMenu {
            Button("Include in Syncs", systemImage: "plus.circle") { onInclude(item) }
        }
    }
}
